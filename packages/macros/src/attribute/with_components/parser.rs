//! Parser utilities for the with_components macro.

use std::collections::HashSet;

use crate::{
    constants::{
        CONSTRUCTOR_ATTRIBUTE, CONTRACT_ATTRIBUTE, EVENT_ENUM_NAME, FLAT_ATTRIBUTE,
        STORAGE_STRUCT_NAME, SUBSTORAGE_ATTRIBUTE,
    },
    utils::tabs,
};
use cairo_lang_defs::patcher::{PatchBuilder, RewriteNode};
use cairo_lang_filesystem::ids::CodeMapping;
use cairo_lang_macro::{Diagnostic, Diagnostics};
use cairo_lang_syntax::node::{
    ast::{self, MaybeModuleBody},
    db::SyntaxGroup,
    SyntaxNode, Terminal, TypedSyntaxNode,
};
use cairo_lang_syntax::node::{
    helpers::{GetIdentifier, QueryAttrs},
    kind::SyntaxKind,
};
use indoc::indoc;

use super::{
    components::{AllowedComponents, ComponentInfo},
    diagnostics::{errors, warnings},
};

#[derive(Debug)]
struct ImportedName {
    source_path: Vec<String>,
    local_name: String,
}

/// Syntax-derived facts used by the lightweight component validation.
///
/// All names and calls are collected from Cairo syntax terminals. Comments and string literals are
/// therefore excluded, while whitespace and path qualification do not affect matching.
#[derive(Default)]
struct ModuleFacts {
    identifiers: HashSet<String>,
    imports: Vec<ImportedName>,
    implemented_traits: Vec<Vec<String>>,
    impl_alias_targets: Vec<Vec<String>>,
    calls: Vec<Vec<String>>,
    constructor_calls: Vec<Vec<String>>,
}

impl ModuleFacts {
    fn collect<'db>(db: &'db dyn SyntaxGroup, body: &ast::ModuleBody<'db>) -> Self {
        let body_node = body.as_syntax_node();
        let identifiers = body_node
            .tokens(db)
            .filter(|node| node.kind(db) == SyntaxKind::TerminalIdentifier)
            .map(|node| terminal_text(db, node))
            .collect();
        let calls = collect_call_paths(db, body_node);

        let mut facts = Self {
            identifiers,
            calls,
            ..Default::default()
        };

        for item in body.items(db).elements(db) {
            match item {
                ast::ModuleItem::Use(item_use) => {
                    collect_imports(db, item_use.use_path(db), &[], &mut facts.imports);
                }
                ast::ModuleItem::Impl(item_impl) => {
                    facts
                        .implemented_traits
                        .push(expr_path_segments(db, item_impl.trait_path(db)));
                }
                ast::ModuleItem::ImplAlias(item_impl_alias) => {
                    facts
                        .impl_alias_targets
                        .push(expr_path_segments(db, item_impl_alias.impl_path(db)));
                }
                ast::ModuleItem::FreeFunction(function)
                    if function.has_attr(db, CONSTRUCTOR_ATTRIBUTE) =>
                {
                    facts.constructor_calls = collect_call_paths(db, function.as_syntax_node());
                }
                _ => {}
            }
        }

        facts
    }

    fn has_identifier(&self, name: &str) -> bool {
        self.identifiers.contains(name)
    }

    fn imports_name(&self, name: &str) -> bool {
        self.imports.iter().any(|import| {
            import
                .source_path
                .last()
                .is_some_and(|segment| segment == name)
        })
    }

    fn imports_name_from(&self, parent_path: &[&str], name: &str) -> bool {
        self.imports.iter().any(|import| {
            import.source_path.len() == parent_path.len() + 1
                && path_starts_with(&import.source_path, parent_path)
                && import
                    .source_path
                    .last()
                    .is_some_and(|segment| segment == name)
        })
    }

    fn implements_trait(&self, trait_name: &str) -> bool {
        self.implemented_traits.iter().any(|path| {
            path.last().is_some_and(|segment| segment == trait_name)
                || path.last().is_some_and(|local_name| {
                    self.imports.iter().any(|import| {
                        import.local_name == *local_name
                            && import
                                .source_path
                                .last()
                                .is_some_and(|segment| segment == trait_name)
                    })
                })
        })
    }

    fn implements_trait_path_suffix(&self, suffix: &[&str]) -> bool {
        self.implemented_traits
            .iter()
            .any(|path| self.path_has_suffix(path, suffix))
    }

    fn implements_imported_trait_from(&self, parent_path: &[&str], trait_name: &str) -> bool {
        self.imports.iter().any(|import| {
            path_starts_with(&import.source_path, parent_path)
                && import
                    .source_path
                    .last()
                    .is_some_and(|segment| segment == trait_name)
                && self
                    .implemented_traits
                    .iter()
                    .any(|path| path.last() == Some(&import.local_name))
        })
    }

    fn has_impl_available(&self, impl_name: &str) -> bool {
        self.imports_name(impl_name)
            || self.impl_alias_targets.iter().any(|path| {
                path.last().is_some_and(|segment| segment == impl_name)
                    || path.last().is_some_and(|local_name| {
                        self.imports.iter().any(|import| {
                            import.local_name == *local_name
                                && import
                                    .source_path
                                    .last()
                                    .is_some_and(|segment| segment == impl_name)
                        })
                    })
            })
    }

    fn has_call(&self, suffix: &[&str]) -> bool {
        self.calls
            .iter()
            .any(|path| self.path_has_suffix(path, suffix))
    }

    fn has_constructor_call(&self, suffix: &[&str]) -> bool {
        self.constructor_calls
            .iter()
            .any(|path| self.path_has_suffix(path, suffix))
    }

    fn path_has_suffix(&self, path: &[String], suffix: &[&str]) -> bool {
        if path_has_suffix(path, suffix) {
            return true;
        }

        let Some((local_name, remaining_path)) = path.split_first() else {
            return false;
        };
        let Some(import) = self
            .imports
            .iter()
            .find(|import| import.local_name == *local_name)
        else {
            return false;
        };

        // Resolve only the leading name imported into this module. The source path is deliberately
        // not expanded again: ModuleFacts is a lexical, syntax-only view without name resolution.
        let mut normalized_path = import.source_path.clone();
        normalized_path.extend_from_slice(remaining_path);
        path_has_suffix(&normalized_path, suffix)
    }
}

fn terminal_text(db: &dyn SyntaxGroup, node: SyntaxNode<'_>) -> String {
    node.get_text_without_trivia(db).long(db).to_string()
}

fn expr_path_segments<'db>(db: &'db dyn SyntaxGroup, path: ast::ExprPath<'db>) -> Vec<String> {
    path.segments(db)
        .elements(db)
        .map(|segment| segment.identifier(db).long(db).to_string())
        .collect()
}

fn collect_imports<'db>(
    db: &'db dyn SyntaxGroup,
    use_path: ast::UsePath<'db>,
    prefix: &[String],
    imports: &mut Vec<ImportedName>,
) {
    match use_path {
        ast::UsePath::Leaf(leaf) => {
            let source_name = leaf.ident(db).identifier(db).long(db).to_string();
            let mut source_path = prefix.to_vec();
            source_path.push(source_name.clone());
            let local_name = match leaf.alias_clause(db) {
                ast::OptionAliasClause::AliasClause(alias) => {
                    alias.alias(db).text(db).long(db).to_string()
                }
                ast::OptionAliasClause::Empty(_) => source_name,
            };
            imports.push(ImportedName {
                source_path,
                local_name,
            });
        }
        ast::UsePath::Single(single) => {
            let mut nested_prefix = prefix.to_vec();
            nested_prefix.push(single.ident(db).identifier(db).long(db).to_string());
            collect_imports(db, single.use_path(db), &nested_prefix, imports);
        }
        ast::UsePath::Multi(multi) => {
            for nested in multi.use_paths(db).elements(db) {
                collect_imports(db, nested, prefix, imports);
            }
        }
        ast::UsePath::Star(_) => {}
    }
}

fn collect_call_paths(db: &dyn SyntaxGroup, node: SyntaxNode<'_>) -> Vec<Vec<String>> {
    let terminals = node
        .tokens(db)
        .map(|terminal| (terminal.kind(db), terminal_text(db, terminal)))
        .collect::<Vec<_>>();
    let mut calls = vec![];

    for (lparen_index, (kind, _)) in terminals.iter().enumerate() {
        if *kind != SyntaxKind::TerminalLParen {
            continue;
        }

        let mut cursor = lparen_index;
        let mut reversed_path = vec![];
        loop {
            if cursor == 0 {
                break;
            }
            cursor -= 1;
            let (kind, text) = &terminals[cursor];
            if *kind != SyntaxKind::TerminalIdentifier {
                break;
            }
            reversed_path.push(text.clone());

            if cursor == 0
                || !matches!(
                    terminals[cursor - 1].0,
                    SyntaxKind::TerminalDot | SyntaxKind::TerminalColonColon
                )
            {
                break;
            }
            cursor -= 1;
        }

        if !reversed_path.is_empty() {
            reversed_path.reverse();
            calls.push(reversed_path);
        }
    }

    calls
}

fn path_starts_with(path: &[String], prefix: &[&str]) -> bool {
    path.len() >= prefix.len()
        && path
            .iter()
            .zip(prefix)
            .all(|(segment, expected)| segment == expected)
}

fn path_has_suffix(path: &[String], suffix: &[&str]) -> bool {
    path.len() >= suffix.len()
        && path[path.len() - suffix.len()..]
            .iter()
            .zip(suffix)
            .all(|(segment, expected)| segment == expected)
}

/// The parser for the with_components macro.
pub struct WithComponentsParser<'a> {
    /// The base node.
    base_node: SyntaxNode<'a>,
    /// The components info.
    components_info: &'a [ComponentInfo<'a>],
}

impl<'a> WithComponentsParser<'a> {
    /// Creates a new parser for the with_components macro.
    pub fn new(base_node: SyntaxNode<'a>, components_info: &'a [ComponentInfo<'a>]) -> Self {
        Self {
            base_node,
            components_info,
        }
    }

    /// Parses the module and returns the patched code plus mappings for copied user source.
    pub fn parse(&mut self, db: &'a dyn SyntaxGroup) -> (String, Vec<CodeMapping>, Diagnostics) {
        let base_node = self.base_node;
        let mut builder = PatchBuilder::new_ex(db, &base_node);

        let typed = ast::SyntaxFile::from_syntax_node(db, base_node);
        let mut base_rnode = RewriteNode::from_ast(&typed);
        let module_rnode = base_rnode.modify_child(db, ast::SyntaxFile::INDEX_ITEMS);

        // If the module has a header doc, skip it
        let module_rnode = if let RewriteNode::Copied(copied) = module_rnode {
            let children = copied.get_children(db);
            // children can't be empty because attribute macros must have at least one item (compiler enforces this)
            if children[0].kind(db) == SyntaxKind::ItemHeaderDoc {
                module_rnode.modify_child(db, 1)
            } else {
                module_rnode.modify_child(db, 0)
            }
        } else {
            module_rnode.modify_child(db, 0)
        };

        // Validate the contract module
        let (errors, mut warnings, module_facts) =
            validate_contract_module(db, module_rnode, self.components_info);
        if !errors.is_empty() {
            return (String::new(), vec![], errors.into());
        }

        // Get the body node
        let body_rnode = module_rnode.modify_child(db, ast::ItemModule::INDEX_BODY);

        process_module_items(body_rnode, db, self.components_info);
        add_use_clauses_and_macros(body_rnode, db, self.components_info);

        builder.add_modified(base_rnode);
        let (content, code_mappings) = builder.build();

        // Add warnings for each component
        for component_info in self.components_info.iter() {
            let component_warnings =
                add_per_component_warnings(&module_facts, component_info, self.components_info);
            warnings.extend(component_warnings);
        }

        (content, code_mappings, warnings.into())
    }
}

/// Validates that the contract module:
///
/// - Has the `#[starknet::contract]` attribute.
/// - Has a constructor calling the corresponding initializers.
/// - Has the corresponding immutable configs.
///
/// NOTE: Missing initializers and configs are added as Warnings.
/// NOTE: When an error is found, the functions doesn't return any warnings to avoid noise.
///
/// # Returns
///
/// * `errors` - The errors that arose during the validation.
/// * `warnings` - The warnings that arose during the validation.
fn validate_contract_module<'db>(
    db: &'db dyn SyntaxGroup,
    node: &mut RewriteNode<'db>,
    components_info: &[ComponentInfo<'_>],
) -> (Vec<Diagnostic>, Vec<Diagnostic>, ModuleFacts) {
    let mut warnings = vec![];

    if let RewriteNode::Copied(copied) = node {
        let item = ast::ItemModule::from_syntax_node(db, *copied);

        // 1. Check that the module has a body (error)
        let MaybeModuleBody::Some(body) = item.body(db) else {
            let error = Diagnostic::error(errors::NO_BODY);
            return (vec![error], vec![], ModuleFacts::default());
        };
        let facts = ModuleFacts::collect(db, &body);

        // 2. Check that the module has the `#[starknet::contract]` attribute (error)
        if !item.has_attr(db, CONTRACT_ATTRIBUTE) {
            let error = Diagnostic::error(errors::NO_CONTRACT_ATTRIBUTE(CONTRACT_ATTRIBUTE));
            return (vec![error], vec![], facts);
        }

        // 3. Ensure only one AccessControl component is used (error)
        let mut accesscontrol_components = vec![];
        for component in components_info.iter() {
            match component.kind() {
                AllowedComponents::AccessControl
                | AllowedComponents::AccessControlDefaultAdminRules => {
                    accesscontrol_components.push(component.short_name());
                }
                _ => {}
            }
        }
        if accesscontrol_components.len() > 1 {
            let components_str = accesscontrol_components.join(", ");
            let error =
                Diagnostic::error(errors::MULTIPLE_ACCESS_CONTROL_COMPONENTS(&components_str));
            return (vec![error], vec![], facts);
        }

        // 4. Disallow ERC721Enumerable and ERC721Consecutive being used together (error)
        let uses_erc721_enumerable = components_info
            .iter()
            .any(|c| matches!(c.kind(), AllowedComponents::ERC721Enumerable))
            || facts.has_identifier("ERC721EnumerableComponent");
        let uses_erc721_consecutive = components_info
            .iter()
            .any(|c| matches!(c.kind(), AllowedComponents::ERC721Consecutive))
            || facts.has_identifier("ERC721ConsecutiveComponent");
        if uses_erc721_enumerable && uses_erc721_consecutive {
            let error = Diagnostic::error(errors::ERC721_BALANCE_OF_INCOPATIBILITY);
            return (vec![error], vec![], facts);
        }

        // 5. Check that the module has the corresponding initializers (warning)
        let components_with_initializer = components_info
            .iter()
            .filter(|c| c.has_initializer)
            .collect::<Vec<&ComponentInfo>>();

        if !components_with_initializer.is_empty() {
            let mut components_with_initializer_missing = vec![];
            for component in components_with_initializer.iter() {
                let initializer_called =
                    facts.has_constructor_call(&["self", component.storage, "initializer"]);
                let no_metadata_initializer_called = matches!(
                    component.kind(),
                    AllowedComponents::ERC721 | AllowedComponents::ERC1155
                ) && facts.has_constructor_call(&[
                    "self",
                    component.storage,
                    "initializer_no_metadata",
                ]);
                if !initializer_called && !no_metadata_initializer_called {
                    components_with_initializer_missing.push(component.short_name());
                }
            }

            if !components_with_initializer_missing.is_empty() {
                let components_with_initializer_missing_str =
                    components_with_initializer_missing.join(", ");
                let warning = Diagnostic::warn(warnings::INITIALIZERS_MISSING(
                    &components_with_initializer_missing_str,
                ));
                warnings.push(warning);
            }
        }

        // 6. Check that the contract has the corresponding immutable configs (warning)
        for component in components_info.iter().filter(|c| c.has_immutable_config) {
            // Case 1: DefaultConfig is imported and used
            let component_parent_path = component
                .path
                .strip_suffix(&component.name)
                .expect("Component path must end with the component name");
            let component_parent_segments = component_parent_path
                .trim_end_matches("::")
                .split("::")
                .collect::<Vec<_>>();
            let default_config_used =
                facts.imports_name_from(&component_parent_segments, "DefaultConfig");
            if default_config_used {
                continue;
            }

            // Case 2: ImmutableConfig is implemented with fully qualified path
            let immutable_config_implemented =
                facts.implements_trait_path_suffix(&[component.name, "ImmutableConfig"]);
            if immutable_config_implemented {
                continue;
            }

            // Case 3: ImmutableConfig is imported (possibly aliased) and implemented
            if facts.implements_imported_trait_from(&component_parent_segments, "ImmutableConfig") {
                continue;
            }

            // No valid config found - add warning
            let warning = Diagnostic::warn(warnings::IMMUTABLE_CONFIG_MISSING(
                component.short_name(),
                &format!("{component_parent_path}DefaultConfig"),
            ));
            warnings.push(warning);
        }

        return (vec![], warnings, facts);
    }

    (vec![], warnings, ModuleFacts::default())
}

/// Adds warnings that may be helpful for users.
fn add_per_component_warnings(
    facts: &ModuleFacts,
    component_info: &ComponentInfo,
    components_info: &[ComponentInfo<'_>],
) -> Vec<Diagnostic> {
    let mut warnings = vec![];

    match component_info.kind() {
        AllowedComponents::Vesting => {
            // Check that the VestingScheduleTrait is implemented
            let linear_impl_used = facts.has_impl_available("LinearVestingSchedule");
            let vesting_trait_used = facts.implements_trait("VestingScheduleTrait");
            if !linear_impl_used && !vesting_trait_used {
                let warning = Diagnostic::warn(warnings::VESTING_SCHEDULE_IMPL_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::Initializable => {
            // Check that the initialize internal function is called
            let initialize_internal_function_called =
                facts.has_call(&["self", "initializable", "initialize"]);
            if !initialize_internal_function_called {
                let warning = Diagnostic::warn(warnings::INITIALIZABLE_NOT_USED);
                warnings.push(warning);
            }
        }
        AllowedComponents::Pausable => {
            // Check that the pause and unpause functions are called
            let pause_function_called = facts.has_call(&["self", "pausable", "pause"]);
            let unpause_function_called = facts.has_call(&["self", "pausable", "unpause"]);
            if !pause_function_called || !unpause_function_called {
                let warning = Diagnostic::warn(warnings::PAUSABLE_NOT_USED);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC20 => {
            // Check that the ERC20HooksTrait is implemented
            let hooks_trait_used = facts.implements_trait("ERC20HooksTrait");
            let hooks_empty_impl_used = facts.has_impl_available("ERC20HooksEmptyImpl");
            if !hooks_trait_used && !hooks_empty_impl_used {
                let warning = Diagnostic::warn(warnings::ERC20_HOOKS_IMPL_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC4626 => {
            // 1. Check that the ERC4626HooksTrait is implemented
            let hooks_trait_used = facts.implements_trait("ERC4626HooksTrait");
            let hooks_empty_impl_used = facts.has_impl_available("ERC4626EmptyHooks");
            if !hooks_trait_used && !hooks_empty_impl_used {
                let warning = Diagnostic::warn(warnings::ERC4626_HOOKS_IMPL_MISSING);
                warnings.push(warning);
            }
            // 2. Check that the FeeConfigTrait is implemented
            let fee_config_trait_used = facts.implements_trait("FeeConfigTrait");
            let fee_config_empty_impl_used = facts.has_impl_available("ERC4626DefaultNoFees");
            if !fee_config_trait_used && !fee_config_empty_impl_used {
                let warning = Diagnostic::warn(warnings::ERC4626_FEE_CONFIG_IMPL_MISSING);
                warnings.push(warning);
            }
            // 3. Check that the LimitConfigTrait is implemented
            let limit_config_trait_used = facts.implements_trait("LimitConfigTrait");
            let limit_config_empty_impl_used = facts.has_impl_available("ERC4626DefaultNoLimits");
            if !limit_config_trait_used && !limit_config_empty_impl_used {
                let warning = Diagnostic::warn(warnings::ERC4626_LIMIT_CONFIG_IMPL_MISSING);
                warnings.push(warning);
            }
            // 4. Check that the AssetsManagementTrait is implemented
            let assets_management_trait_used = facts.implements_trait("AssetsManagementTrait");
            let self_assets_management_impl_used =
                facts.has_impl_available("ERC4626SelfAssetsManagement");
            if !assets_management_trait_used && !self_assets_management_impl_used {
                let warning = Diagnostic::warn(warnings::ERC4626_ASSETS_MANAGEMENT_IMPL_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC721 => {
            // Check that the ERC721HooksTrait is implemented
            let hooks_trait_used = facts.implements_trait("ERC721HooksTrait");
            let hooks_empty_impl_used = facts.has_impl_available("ERC721HooksEmptyImpl");
            if !hooks_trait_used && !hooks_empty_impl_used {
                let warning = Diagnostic::warn(warnings::ERC721_HOOKS_IMPL_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC1155 => {
            // Check that the ERC1155HooksTrait is implemented
            let hooks_trait_used = facts.implements_trait("ERC1155HooksTrait");
            let hooks_empty_impl_used = facts.has_impl_available("ERC1155HooksEmptyImpl");
            if !hooks_trait_used && !hooks_empty_impl_used {
                let warning = Diagnostic::warn(warnings::ERC1155_HOOKS_IMPL_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC6909 => {
            // Check that the ERC6909HooksTrait is implemented
            let hooks_trait_used = facts.implements_trait("ERC6909HooksTrait");
            let hooks_empty_impl_used = facts.has_impl_available("ERC6909HooksEmptyImpl");
            if !hooks_trait_used && !hooks_empty_impl_used {
                let warning = Diagnostic::warn(warnings::ERC6909_HOOKS_IMPL_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC1155Supply => {
            let hook_called = facts.has_call(&["erc1155_supply", "after_update"])
                || facts.has_call(&["ERC1155SupplyInternalImpl", "after_update"]);
            if !hook_called {
                let warning = Diagnostic::warn(warnings::ERC1155_SUPPLY_HOOKS_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC6909TokenSupply => {
            let hook_called = facts.has_call(&["erc6909_token_supply", "update_token_supply"])
                || facts.has_call(&["ERC6909TokenSupplyInternalImpl", "update_token_supply"]);
            if !hook_called {
                let warning = Diagnostic::warn(warnings::ERC6909_TOKEN_SUPPLY_HOOKS_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::Upgradeable => {
            // Check that the upgrade function is called
            let upgrade_function_called = facts.has_call(&["self", "upgradeable", "upgrade"]);
            if !upgrade_function_called {
                let warning = Diagnostic::warn(warnings::UPGRADEABLE_NOT_USED);
                warnings.push(warning);
            }
        }
        AllowedComponents::Votes => {
            // Check that the SNIP12Metadata is implemented
            let snip12_metadata_implemented = facts.implements_trait("SNIP12Metadata");
            if !snip12_metadata_implemented {
                let warning = Diagnostic::warn(warnings::SNIP12_METADATA_IMPL_MISSING);
                warnings.push(warning);
            }

            // Token integrations must forward token updates to Votes.
            let uses_token_component = components_info.iter().any(|component| {
                matches!(
                    component.kind(),
                    AllowedComponents::ERC20
                        | AllowedComponents::ERC20FlashMint
                        | AllowedComponents::ERC721
                        | AllowedComponents::ERC721Consecutive
                )
            });
            let hook_called = facts.has_call(&["votes", "transfer_voting_units"])
                || facts.has_call(&["VotesInternalImpl", "transfer_voting_units"]);
            if uses_token_component && !hook_called {
                let warning = Diagnostic::warn(warnings::VOTES_HOOKS_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC721Enumerable => {
            let hook_called = facts.has_call(&["erc721_enumerable", "before_update"])
                || facts.has_call(&["ERC721EnumerableInternalImpl", "before_update"]);
            if !hook_called {
                let warning = Diagnostic::warn(warnings::ERC721_ENUMERABLE_HOOKS_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC721URIStorage => {
            let hook_called = facts.has_call(&["erc721_uri_storage", "after_update"])
                || facts.has_call(&["ERC721URIStorageInternalImpl", "after_update"]);
            if !hook_called {
                let warning = Diagnostic::warn(warnings::ERC721_URI_STORAGE_HOOKS_MISSING);
                warnings.push(warning);
            }
        }
        AllowedComponents::ERC721Consecutive => {
            let before_update_called = facts.has_call(&["erc721_consecutive", "before_update"])
                || facts.has_call(&["ERC721ConsecutiveInternalImpl", "before_update"]);
            let after_update_called = facts.has_call(&["erc721_consecutive", "after_update"])
                || facts.has_call(&["ERC721ConsecutiveInternalImpl", "after_update"]);
            if !before_update_called || !after_update_called {
                let warning = Diagnostic::warn(warnings::ERC721_CONSECUTIVE_HOOKS_MISSING);
                warnings.push(warning);
            }
        }
        _ => {}
    }
    warnings
}

/// Iterates over the items in the body node and processes them.
fn process_module_items<'db>(
    body_rnode: &mut RewriteNode<'db>,
    db: &'db dyn SyntaxGroup,
    components_info: &[ComponentInfo<'_>],
) {
    let items_rnode = body_rnode.modify_child(db, ast::ModuleBody::INDEX_ITEMS);
    let items_mnode = items_rnode.modify(db);
    let mut event_enum_found = false;

    for item_rnode in items_mnode.children.as_mut().unwrap() {
        if let RewriteNode::Copied(copied) = item_rnode {
            let item = ast::ModuleItem::from_syntax_node(db, *copied);

            match item {
                ast::ModuleItem::Struct(item_struct)
                    if item_struct.name(db).text(db).long(db).as_str() == STORAGE_STRUCT_NAME =>
                {
                    process_storage_struct(item_rnode, db, components_info);
                }
                ast::ModuleItem::Enum(item_enum)
                    if item_enum.name(db).text(db).long(db).as_str() == EVENT_ENUM_NAME =>
                {
                    process_event_enum(item_rnode, db, components_info);
                    event_enum_found = true;
                }
                _ => {}
            }
        }
    }

    // If the event enum is not found, add it.
    if !event_enum_found {
        add_event_enum(body_rnode, db, components_info);
    }
}

/// Modifies the storage struct to add the component entries.
fn process_storage_struct<'db>(
    item_struct: &mut RewriteNode<'db>,
    db: &'db dyn SyntaxGroup,
    components_info: &[ComponentInfo<'_>],
) {
    let item_struct_mnode = item_struct.modify(db);
    let item_struct_children = item_struct_mnode.children.as_mut().unwrap();
    let components_rnode =
        ComponentsGenerationData(components_info).generate_for_storage_struct(db);

    // Insert the components at the beginning of the struct body.
    item_struct_children.insert(ast::ItemStruct::INDEX_LBRACE + 1, components_rnode);
}

/// Modifies the event enum to add the component events.
fn process_event_enum<'db>(
    item_enum: &mut RewriteNode<'db>,
    db: &'db dyn SyntaxGroup,
    components_info: &[ComponentInfo<'_>],
) {
    let item_enum_mnode = item_enum.modify(db);
    let item_enum_children = item_enum_mnode.children.as_mut().unwrap();
    let components_rnode = ComponentsGenerationData(components_info).generate_for_event_enum(db);

    // Insert the components at the beginning of the enum body.
    item_enum_children.insert(ast::ItemEnum::INDEX_LBRACE + 1, components_rnode);
}

fn add_event_enum<'db>(
    body_rnode: &mut RewriteNode<'db>,
    db: &'db dyn SyntaxGroup,
    components_info: &[ComponentInfo<'_>],
) {
    let body_mnode = body_rnode.modify(db);
    let event_enum_rnode = ComponentsGenerationData(components_info).generate_event_enum(db);

    // It is safe to unwrap here because we know that the node has at least the storage struct children
    body_mnode
        .children
        .as_mut()
        .unwrap()
        .insert(ast::ModuleBody::INDEX_RBRACE, event_enum_rnode);
}

/// Modifies the body node to add the use clauses and the `component!` macros to the module.
fn add_use_clauses_and_macros<'db>(
    body_rnode: &mut RewriteNode<'db>,
    db: &'db dyn SyntaxGroup,
    components_info: &[ComponentInfo<'_>],
) {
    let body_mnode = body_rnode.modify(db);
    let components_rnode = ComponentsGenerationData(components_info).generate_for_module(db);

    // It is safe to unwrap here because we know that the node has at least the storage struct children
    body_mnode
        .children
        .as_mut()
        .unwrap()
        .insert(ast::ModuleBody::INDEX_RBRACE, components_rnode);
}

/// Set of component information to be used for code generation.
struct ComponentsGenerationData<'a>(&'a [ComponentInfo<'a>]);

impl<'a> ComponentsGenerationData<'a> {
    fn generate_for_module<'db>(self, _db: &'db dyn SyntaxGroup) -> RewriteNode<'db> {
        RewriteNode::interpolate_patched(
            indoc! {"

        $component_use_clause_entries$

        $component_macro_entries$

        $component_internal_impls_entries$
        "},
            &[
                (
                    "component_use_clause_entries".to_string(),
                    self.component_use_clause_entries(),
                ),
                (
                    "component_macro_entries".to_string(),
                    self.component_macro_entries(),
                ),
                (
                    "component_internal_impls_entries".to_string(),
                    self.component_internal_impls_entries(),
                ),
            ]
            .into(),
        )
    }

    fn generate_for_storage_struct<'db>(self, _db: &'db dyn SyntaxGroup) -> RewriteNode<'db> {
        let mut entries = vec![];
        for component in self.0.iter() {
            entries.push(format!("{}#[{}]", tabs(2), SUBSTORAGE_ATTRIBUTE));
            entries.push(format!(
                "{}pub {}: {}::Storage,",
                tabs(2),
                component.storage,
                component.name
            ));
        }
        RewriteNode::Text(entries.join("\n") + "\n")
    }

    fn generate_for_event_enum<'db>(self, _db: &'db dyn SyntaxGroup) -> RewriteNode<'db> {
        let mut entries = vec![];
        for component in self.0.iter() {
            entries.push(format!("{}#[{}]", tabs(2), FLAT_ATTRIBUTE));
            entries.push(format!(
                "{}{}: {}::Event,",
                tabs(2),
                component.event,
                component.name
            ));
        }
        RewriteNode::Text(entries.join("\n") + "\n")
    }

    fn generate_event_enum<'db>(self, _db: &'db dyn SyntaxGroup) -> RewriteNode<'db> {
        let mut entries = vec![];

        entries.push(format!("\n{}#[event]", tabs(1)));
        entries.push(format!("{}#[derive(Drop, starknet::Event)]", tabs(1)));
        entries.push(format!("{}enum {} {{", tabs(1), EVENT_ENUM_NAME));
        for component in self.0.iter() {
            entries.push(format!("{}#[{}]", tabs(2), FLAT_ATTRIBUTE));
            entries.push(format!(
                "{}{}: {}::Event,",
                tabs(2),
                component.event,
                component.name
            ));
        }
        entries.push(format!("{}}}", tabs(1)));
        RewriteNode::Text(entries.join("\n"))
    }

    fn component_use_clause_entries<'db>(&self) -> RewriteNode<'db> {
        let mut entries = vec![];
        for component in self.0.iter() {
            entries.push(format!("{}use {};", tabs(1), component.path));
        }
        RewriteNode::Text(entries.join("\n"))
    }

    fn component_macro_entries<'db>(&self) -> RewriteNode<'db> {
        let mut entries = vec![];
        for component in self.0.iter() {
            entries.push(format!(
                "{}component!(path: {}, storage: {}, event: {});",
                tabs(1),
                component.name,
                component.storage,
                component.event
            ));
        }
        RewriteNode::Text(entries.join("\n"))
    }

    fn component_internal_impls_entries<'db>(&self) -> RewriteNode<'db> {
        let mut entries = vec![];
        for component in self.0.iter() {
            for implementation in component.internal_impls.iter() {
                entries.push(format!(
                    "{}impl {}{} = {}::{}<ContractState>;",
                    tabs(1),
                    component.short_name(),
                    implementation,
                    component.name,
                    implementation
                ));
            }
        }
        RewriteNode::Text(entries.join("\n"))
    }
}
