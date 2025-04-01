use cairo_lang_formatter::format_string;
use cairo_lang_macro::{derive_macro, Diagnostic, Diagnostics, ProcMacroResult, TokenStream};
use cairo_lang_parser::utils::SimpleParserDatabase;
use cairo_lang_plugins::plugins::utils::PluginTypeInfo;
use cairo_lang_starknet_classes::keccak::starknet_keccak;
use cairo_lang_syntax::node::{ast, TypedSyntaxNode};
use cairo_lang_syntax::node::{db::SyntaxGroup, SyntaxNode};
use convert_case::{Case, Casing};
use indoc::formatdoc;

use crate::type_hash::parser::TypeHashParser;

use super::diagnostics::errors;

/// Derive macro that generates a SNIP-12 type hash constant for a struct.
#[derive_macro]
pub fn type_hash(item_stream: TokenStream) -> ProcMacroResult {
    // 1. Parse the item stream
    let db = SimpleParserDatabase::default();
    let content = match db.parse_virtual(item_stream.to_string()) {
        Ok(node) => handle_node(&db, node),
        Err(err) => {
            let error = Diagnostic::error(err.format(&db));
            return ProcMacroResult::new(TokenStream::empty()).with_diagnostics(error.into());
        }
    };

    // 2. Format the expanded content
    let (formatted_content, diagnostics) = match content {
        Ok(content) => (format_string(&db, content), Diagnostics::new(vec![])),
        Err(err) => (String::new(), err.into()),
    };

    // 3. Return the result
    ProcMacroResult::new(TokenStream::new(formatted_content)).with_diagnostics(diagnostics)
}

fn handle_node(db: &dyn SyntaxGroup, node: SyntaxNode) -> Result<String, Diagnostic> {
    let typed = ast::SyntaxFile::from_syntax_node(db, node);
    let items = typed.items(db).elements(db);

    let Some(item_ast) = items.first() else {
        let error = Diagnostic::error(errors::EMPTY_TYPE_FOUND);
        return Err(error);
    };

    // Generate type hash for structs/enums only
    match item_ast {
        ast::ModuleItem::Struct(_) | ast::ModuleItem::Enum(_) => {
            // It is safe to unwrap here because we know the item is a struct
            let plugin_type_info = PluginTypeInfo::new(db, &item_ast).unwrap();
            generate_code(db, &plugin_type_info)
        }
        _ => {
            let error = Diagnostic::error(errors::NOT_VALID_TYPE_FOR_DERIVE);
            Err(error)
        }
    }
}

/// Generates the code for the type hash constant.
fn generate_code(
    db: &dyn SyntaxGroup,
    plugin_type_info: &PluginTypeInfo,
) -> Result<String, Diagnostic> {
    let mut parser = TypeHashParser::new(plugin_type_info);
    let type_hash_string = parser.parse(db)?;
    let type_hash = starknet_keccak(type_hash_string.as_bytes());
    let type_name = plugin_type_info.name.as_str().to_case(Case::UpperSnake);

    let code = formatdoc!(
        "
        // selector!(
        //   \"{}\"
        // );
        pub const {type_name}_TYPE_HASH: felt252 = 0x{:x};
        ",
        type_hash_string.replace("\"", "\\\""),
        type_hash
    );

    Ok(code)
}
