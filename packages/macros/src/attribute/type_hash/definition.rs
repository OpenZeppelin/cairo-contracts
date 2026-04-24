use cairo_lang_macro::{attribute_macro, Diagnostic, ProcMacroResult, TokenStream};
use cairo_lang_parser::utils::SimpleParserDatabase;
use cairo_lang_plugins::plugins::utils::PluginTypeInfo;
use cairo_lang_starknet_classes::keccak::starknet_keccak;
use cairo_lang_syntax::node::{ast, TypedSyntaxNode};
use cairo_lang_syntax::node::{db::SyntaxGroup, SyntaxNode};
use convert_case::{Case, Casing};
use indoc::formatdoc;

use crate::attribute::common::{
    args::split_top_level_args,
    token_stream::{append_generated_code, parse_macro_input},
};
use crate::type_hash::parser::TypeHashParser;

use super::diagnostics::errors;
use super::parser::{parse_snip12_args, parse_string_arg};

/// Derive macro that generates a SNIP-12 type hash constant for a struct.
///
/// Example:
/// ```
/// #[type_hash]
/// pub struct MyStruct {
///     pub some_member: felt252,
/// }
///
/// // Generates:
/// pub const MY_STRUCT_TYPE_HASH: felt252 = 0x[HASH];
/// ```
#[attribute_macro]
pub fn type_hash(attr_stream: TokenStream, item_stream: TokenStream) -> ProcMacroResult {
    let no_op_result = ProcMacroResult::new(item_stream.clone());

    // 1. Parse the attribute stream
    let config = match parse_args(&attr_stream.to_string()) {
        Ok(config) => config,
        Err(err) => {
            return no_op_result.with_diagnostics(err.into());
        }
    };

    // 2. Parse the item stream
    let db = SimpleParserDatabase::default();
    let content = match parse_macro_input(&db, &item_stream) {
        Ok(node) => handle_node(&db, node, &config),
        Err(diagnostic) => {
            return no_op_result.with_diagnostics(diagnostic.into());
        }
    };

    let generated = match content {
        Ok(generated) => generated,
        Err(err) => {
            return no_op_result.with_diagnostics(err.into());
        }
    };

    // 3. Preserve the original item tokens and append generated code with call-site spans
    match append_generated_code(&db, item_stream, generated) {
        Ok(token_stream) => ProcMacroResult::new(token_stream),
        Err(diagnostic) => no_op_result.with_diagnostics(diagnostic.into()),
    }
}

/// This attribute macro is used to specify an override for the SNIP-12 type.
///
/// It doesn't modify the source code directly, but it is used in the type hash parser to generate the new type hash.
///
/// Example:
/// ```
/// #[type_hash]
/// pub struct MyStruct {
///     #[snip12(name: "Some Member", kind: "shortstring")]
///     pub some_member: felt252,
/// }
/// ```
#[attribute_macro]
pub fn snip12(attr_stream: TokenStream, item_stream: TokenStream) -> ProcMacroResult {
    match parse_snip12_args(&attr_stream.to_string()) {
        Ok(_) => ProcMacroResult::new(item_stream),
        Err(error) => ProcMacroResult::new(item_stream).with_diagnostics(error.into()),
    }
}

/// Configuration for the type hash attribute.
///
/// Represents the arguments passed to the type_hash attribute.
///
/// Example:
/// ```
/// #[type_hash(name: "MyStruct", debug: true)]
/// ```
pub struct TypeHashArgs {
    pub name: String,
    pub debug: bool,
}

/// Parses the arguments passed to the type_hash attribute and
/// returns a TypeHashArgs struct containing the parsed arguments.
fn parse_args(s: &str) -> Result<TypeHashArgs, Diagnostic> {
    let mut args = TypeHashArgs {
        name: String::new(),
        debug: false,
    };
    let mut name_seen = false;
    let mut debug_seen = false;

    // If the attribute is empty, return the default config
    let s = s.trim();
    if s.is_empty() || s == "()" {
        return Ok(args);
    }

    let Some(s) = s.strip_prefix('(').and_then(|s| s.strip_suffix(')')) else {
        return Err(Diagnostic::error(
            errors::INVALID_TYPE_HASH_ATTRIBUTE_FORMAT,
        ));
    };

    let Some(parts) = split_top_level_args(s) else {
        return Err(Diagnostic::error(
            errors::INVALID_TYPE_HASH_ATTRIBUTE_FORMAT,
        ));
    };

    for arg in parts {
        let Some((name, value)) = arg.split_once(':') else {
            return Err(Diagnostic::error(
                errors::INVALID_TYPE_HASH_ATTRIBUTE_FORMAT,
            ));
        };

        match name.trim() {
            "name" => {
                if name_seen {
                    return Err(Diagnostic::error(
                        errors::INVALID_TYPE_HASH_ATTRIBUTE_FORMAT,
                    ));
                }
                args.name = parse_string_arg(value.trim())?;
                name_seen = true;
            }
            "debug" => {
                if debug_seen {
                    return Err(Diagnostic::error(
                        errors::INVALID_TYPE_HASH_ATTRIBUTE_FORMAT,
                    ));
                }
                args.debug = parse_bool_arg(value.trim())?;
                debug_seen = true;
            }
            _ => {
                return Err(Diagnostic::error(
                    errors::INVALID_TYPE_HASH_ATTRIBUTE_FORMAT,
                ))
            }
        }
    }

    Ok(args)
}

fn parse_bool_arg(s: &str) -> Result<bool, Diagnostic> {
    match s {
        "true" => Ok(true),
        "false" => Ok(false),
        _ => Err(Diagnostic::error(
            errors::INVALID_TYPE_HASH_ATTRIBUTE_FORMAT,
        )),
    }
}

fn handle_node(
    db: &dyn SyntaxGroup,
    node: SyntaxNode<'_>,
    args: &TypeHashArgs,
) -> Result<String, Diagnostic> {
    let typed = ast::SyntaxFile::from_syntax_node(db, node);
    let mut items = typed.items(db).elements(db);

    let Some(item_ast) = items.next() else {
        let error = Diagnostic::error(errors::EMPTY_TYPE_FOUND);
        return Err(error);
    };

    // Generate type hash for structs/enums only
    match item_ast {
        ast::ModuleItem::Struct(_) | ast::ModuleItem::Enum(_) => {
            let Some(plugin_type_info) = PluginTypeInfo::new(db, &item_ast) else {
                return Err(Diagnostic::error(errors::NOT_VALID_TYPE_TO_DECORATE));
            };
            generate_code(db, &plugin_type_info, args)
        }
        _ => {
            let error = Diagnostic::error(errors::NOT_VALID_TYPE_TO_DECORATE);
            Err(error)
        }
    }
}

/// Generates the code for the type hash constant.
fn generate_code(
    db: &dyn SyntaxGroup,
    plugin_type_info: &PluginTypeInfo<'_>,
    args: &TypeHashArgs,
) -> Result<String, Diagnostic> {
    let mut parser = TypeHashParser::new(plugin_type_info);
    let type_hash_string = parser.parse(db, args)?;
    let type_hash = starknet_keccak(type_hash_string.as_bytes());
    let type_name = plugin_type_info.name.to_case(Case::UpperSnake);

    let debug_string = if args.debug {
        formatdoc!(
            r#"
            pub fn __{type_name}_encoded_type() {{
                println!("{}");
            }}"#,
            type_hash_string.replace("\"", "\\\"")
        )
    } else {
        String::new()
    };

    let code = formatdoc!(
        "
        {debug_string}
        pub const {type_name}_TYPE_HASH: felt252 = 0x{:x};

        ",
        type_hash
    );

    Ok(code)
}

#[cfg(test)]
mod tests {
    use super::parse_args;

    #[test]
    fn rejects_duplicate_name_argument() {
        assert!(parse_args(r#"(name: "A", name: "B")"#).is_err());
    }

    #[test]
    fn rejects_duplicate_debug_argument() {
        assert!(parse_args("(debug: true, debug: false)").is_err());
    }
}
