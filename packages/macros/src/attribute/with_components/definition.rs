use cairo_lang_macro::{attribute_macro, Diagnostic, ProcMacroResult, TokenStream};
use cairo_lang_parser::utils::SimpleParserDatabase;

use crate::{
    attribute::common::{
        args::split_top_level_args,
        token_stream::{mapped_code_token_stream, parse_macro_input},
    },
    with_components::{components::AllowedComponents, parser::WithComponentsParser},
};

use super::diagnostics::errors;

/// Inserts multiple component dependencies into a modules codebase.
#[attribute_macro]
pub fn with_components(attribute_stream: TokenStream, item_stream: TokenStream) -> ProcMacroResult {
    let no_op_result = ProcMacroResult::new(item_stream.clone());

    let args = match parse_component_args(&attribute_stream.to_string()) {
        Ok(args) => args,
        Err(err) => {
            return no_op_result.with_diagnostics(err.into());
        }
    };

    // 1. Get the components info (if valid)
    let mut components_info = vec![];
    for arg in args {
        let maybe_component = AllowedComponents::from_str(&arg);
        match maybe_component {
            Ok(component) => {
                components_info.push(component.get_info());
            }
            Err(err) => {
                return no_op_result.with_diagnostics(err.into());
            }
        }
    }

    // 2. Parse the item stream
    let db = SimpleParserDatabase::default();
    let (content, code_mappings, diagnostics) = match parse_macro_input(&db, &item_stream) {
        Ok(node) => WithComponentsParser::new(node, &components_info).parse(&db),
        Err(diagnostic) => {
            return no_op_result.with_diagnostics(diagnostic.into());
        }
    };

    // 3. Tokenize the patched module, preserving spans for copied user code.
    let token_stream = match mapped_code_token_stream(
        &db,
        content,
        &code_mappings,
        item_stream.metadata().clone(),
    ) {
        Ok(token_stream) => token_stream,
        Err(diagnostic) => {
            return no_op_result.with_diagnostics(diagnostic.into());
        }
    };

    ProcMacroResult::new(token_stream).with_diagnostics(diagnostics)
}

/// Parses the arguments from the attribute stream.
#[cfg(test)]
fn parse_args(text: &str) -> Vec<String> {
    parse_component_args(text).unwrap_or_default()
}

/// Parses and validates `with_components` attribute arguments.
///
/// The macro accepts either `Component` or `(ComponentA, ComponentB)` syntax. Unlike regex-based
/// parsing, this rejects malformed separators instead of silently extracting every identifier.
fn parse_component_args(text: &str) -> Result<Vec<String>, Diagnostic> {
    let text = text.trim();
    if text.is_empty() || text == "()" {
        return Ok(vec![]);
    }

    let inner = if let Some(inner) = text.strip_prefix('(') {
        inner
            .strip_suffix(')')
            .ok_or_else(invalid_attribute_format)?
    } else if text.ends_with(')') {
        return Err(invalid_attribute_format());
    } else {
        text
    };

    let mut parts = split_top_level_args(inner).ok_or_else(invalid_attribute_format)?;
    if parts.last() == Some(&"") {
        parts.pop();
    }

    if parts.is_empty()
        || parts
            .iter()
            .any(|part| part.is_empty() || !is_component_identifier(part))
    {
        return Err(invalid_attribute_format());
    }

    Ok(parts.into_iter().map(str::to_owned).collect())
}

fn is_component_identifier(s: &str) -> bool {
    let mut chars = s.chars();
    let Some(first) = chars.next() else {
        return false;
    };

    (first.is_ascii_alphabetic() || first == '_')
        && chars.all(|ch| ch.is_ascii_alphanumeric() || ch == '_')
}

fn invalid_attribute_format() -> Diagnostic {
    Diagnostic::error(errors::INVALID_ATTRIBUTE_FORMAT)
}

#[cfg(test)]
mod tests {
    use super::parse_args;

    #[test]
    fn test_parse_args() {
        let attribute = "(ERC20, Ownable)";
        let result = parse_args(attribute);
        assert_eq!(result, vec!["ERC20", "Ownable"]);

        let attribute = "ERC20";
        let result = parse_args(attribute);
        assert_eq!(result, vec!["ERC20"]);

        let attribute = "(Ownable, ERC20, Other, Another)";
        let result = parse_args(attribute);
        assert_eq!(result, vec!["Ownable", "ERC20", "Other", "Another"]);
    }
}
