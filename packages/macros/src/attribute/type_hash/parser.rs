//! Parser utilities for the type hash macro.

use std::collections::HashSet;

use cairo_lang_macro::Diagnostic;
use cairo_lang_plugins::plugins::utils::{PluginTypeInfo, TypeVariant};
use cairo_lang_syntax::node::TypedSyntaxNode;
use cairo_lang_syntax::{node::ast::Attribute, node::db::SyntaxGroup};

use crate::attribute::common::args::split_top_level_args;

use super::definition::TypeHashArgs;
use super::diagnostics::errors;
use super::types::{is_reserved_type_name, split_types, InnerType, S12Type};

const SNIP12_TYPE_ATTRIBUTE: &str = "snip12";

/// The parser for the type hash macro.
///
/// It parses the members of the struct or enum and maintains a list of types including referenced objects/enums.
pub struct TypeHashParser<'db, 'a> {
    /// The plugin type info object.
    plugin_type_info: &'a PluginTypeInfo<'db>,
    /// Quick lookup for already processed types.
    is_type_processed: HashSet<String>,
    /// The encode type of the objects/enums referenced in the input that have already been processed.
    /// HashSet is used to avoid duplicates.
    processed_ref_encoded_types: HashSet<String>,
}

impl<'db, 'a> TypeHashParser<'db, 'a> {
    /// Creates a new parser for the type hash macro from a plugin type info object.
    pub fn new(plugin_type_info: &'a PluginTypeInfo<'db>) -> Self {
        let is_type_processed = HashSet::new();
        let processed_ref_encoded_types = HashSet::new();

        Self {
            plugin_type_info,
            is_type_processed,
            processed_ref_encoded_types,
        }
    }

    /// Parses the object/enum and returns the encoded type.
    pub fn parse(
        &mut self,
        db: &'db dyn SyntaxGroup,
        args: &TypeHashArgs,
    ) -> Result<String, Diagnostic> {
        let primary_type_name = if args.name.is_empty() {
            self.plugin_type_info.name
        } else {
            &args.name
        };
        if is_reserved_type_name(primary_type_name) {
            return Err(Diagnostic::error(errors::RESERVED_SNIP12_TYPE_NAME(
                primary_type_name,
            )));
        }

        // 1. Get the members types real values from mapping and attributes
        let members_types = self
            .plugin_type_info
            .members_info
            .iter()
            .map(|member| {
                let attributes = member.attributes.elements(db).collect::<Vec<_>>();
                let args = match get_name_and_type_from_attributes(db, &attributes) {
                    Ok(args) => args,
                    Err(e) => {
                        return Err(e);
                    }
                };
                let attr_name = args.name;
                let attr_type = args.kind;

                // If there is an attribute, use it, otherwise use the type from the member
                let type_input = if !attr_type.is_empty() {
                    attr_type.clone()
                } else {
                    member.ty.to_string()
                };
                let s12_type = if attr_type.is_empty() {
                    S12Type::from_cairo_type(&type_input)
                } else {
                    S12Type::from_str(&type_input)
                };

                // If there is an attribute, use it, otherwise use the name from the member
                let s12_name = if !attr_name.is_empty() {
                    attr_name
                } else {
                    member.name.to_string()
                };

                let Some(s12_type) = s12_type else {
                    return Err(Diagnostic::error(errors::INVALID_SNIP12_TYPE(&type_input)));
                };

                Ok((s12_name, s12_type))
            })
            .collect::<Vec<Result<(String, S12Type), Diagnostic>>>();

        // 2. Build the string representation
        let mut encoded_type = format!("{}(", encode_json_string(primary_type_name));
        let mut member_names = HashSet::new();
        for result in members_types {
            let (name, s12_type) = result?;
            if !member_names.insert(name.clone()) {
                return Err(Diagnostic::error(errors::DUPLICATE_SNIP12_NAME(&name)));
            }
            let type_name = s12_type.get_snip12_type_name()?;
            let encoded_name = encode_json_string(&name);

            // Format the member depending on the type variant
            match self.plugin_type_info.type_variant {
                TypeVariant::Struct => {
                    encoded_type.push_str(&format!("{encoded_name}:\"{type_name}\","))
                }
                TypeVariant::Enum => {
                    let tuple = maybe_tuple(&type_name)?;
                    encoded_type.push_str(&format!("{encoded_name}({tuple}),"))
                }
            };

            if !self.is_type_processed.contains(&type_name) {
                let (encoded_type, inner_types) = s12_type.get_encoded_ref_type()?;
                self.processed_ref_encoded_types.insert(encoded_type);
                self.is_type_processed.insert(type_name);

                // Process inner types
                self.process_inner_types(&inner_types);
            }
        }
        if encoded_type.ends_with(",") {
            encoded_type.pop();
        }
        encoded_type.push(')');

        let mut processed_ref_encoded_types =
            self.processed_ref_encoded_types.iter().collect::<Vec<_>>();
        processed_ref_encoded_types.sort();
        for processed_type in processed_ref_encoded_types {
            encoded_type.push_str(processed_type);
        }

        // 3. Return the encoded type
        Ok(encoded_type)
    }

    fn process_inner_types(&mut self, inner_types: &[InnerType]) {
        for inner_type in inner_types {
            if !self.is_type_processed.contains(&inner_type.name) {
                self.processed_ref_encoded_types
                    .insert(inner_type.encoded_type.clone());
                self.is_type_processed.insert(inner_type.name.clone());
            }
        }
    }
}

/// Gets the name and type from the attributes.
///
/// The expected attribute is of the form:
/// ```
/// #[snip12(name: <name>, kind: <type>)]
/// ```
/// or
/// ```
/// #[snip12(kind: <type>)]
/// ```
/// or
/// ```
/// #[snip12(name: <name>)]
fn get_name_and_type_from_attributes(
    db: &dyn SyntaxGroup,
    attributes: &[Attribute],
) -> Result<Snip12Args, Diagnostic> {
    let mut snip12_args = None;
    for attribute in attributes {
        let attribute_text = attribute.as_syntax_node().get_text_without_trivia(db);
        let Some(arguments) = snip12_attribute_arguments(attribute_text.long(db).as_str()) else {
            continue;
        };
        if snip12_args.is_some() {
            return Err(Diagnostic::error(errors::MULTIPLE_SNIP12_ATTRIBUTES));
        }
        snip12_args = Some(parse_snip12_args(arguments)?);
    }
    Ok(snip12_args.unwrap_or(Snip12Args {
        name: String::new(),
        kind: String::new(),
    }))
}

/// Extracts the argument section from a `#[snip12(...)]` attribute.
///
/// Cairo's formatter may add whitespace between the attribute name and the argument list. Parsing
/// this directly avoids depending on one exact string representation of the attribute.
fn snip12_attribute_arguments(attribute_text: &str) -> Option<&str> {
    let inner = attribute_text
        .trim()
        .strip_prefix("#[")?
        .strip_suffix(']')?
        .trim();

    let rest = inner.strip_prefix(SNIP12_TYPE_ATTRIBUTE)?;
    let rest = rest.trim_start();
    if rest.is_empty() || rest.starts_with('(') {
        Some(rest)
    } else {
        None
    }
}

/// Arguments for the snip12 attribute.
///
/// Represents the arguments passed to the snip12 attribute.
///
/// Example:
/// ```
/// #[snip12(name: "MyStruct", kind: "struct")]
/// ```
#[derive(Debug)]
pub struct Snip12Args {
    pub name: String,
    pub kind: String,
}

/// Parses the arguments passed to the snip12 attribute and
/// returns a Snip12Args struct containing the parsed arguments.
pub(crate) fn parse_snip12_args(s: &str) -> Result<Snip12Args, Diagnostic> {
    // Initialize the args with the default values
    let mut args = Snip12Args {
        name: String::new(),
        kind: String::new(),
    };
    let mut name_seen = false;
    let mut kind_seen = false;

    // If the attribute is empty, return the default args
    let s = s.trim();
    if s.is_empty() {
        return Err(Diagnostic::error(errors::INVALID_SNIP12_ATTRIBUTE_FORMAT));
    }
    if s == "()" {
        return Ok(args);
    }

    let Some(s) = s.strip_prefix('(').and_then(|s| s.strip_suffix(')')) else {
        return Err(Diagnostic::error(errors::INVALID_SNIP12_ATTRIBUTE_FORMAT));
    };

    let Some(parts) = split_top_level_args(s) else {
        return Err(Diagnostic::error(errors::INVALID_SNIP12_ATTRIBUTE_FORMAT));
    };

    for arg in parts {
        let Some((name, value)) = arg.split_once(':') else {
            return Err(Diagnostic::error(errors::INVALID_SNIP12_ATTRIBUTE_FORMAT));
        };

        match name.trim() {
            "name" => {
                if name_seen {
                    return Err(Diagnostic::error(errors::INVALID_SNIP12_ATTRIBUTE_FORMAT));
                }
                args.name = parse_string_arg(value.trim())?;
                name_seen = true;
            }
            "kind" => {
                if kind_seen {
                    return Err(Diagnostic::error(errors::INVALID_SNIP12_ATTRIBUTE_FORMAT));
                }
                args.kind = parse_string_arg(value.trim())?;
                kind_seen = true;
            }
            _ => return Err(Diagnostic::error(errors::INVALID_SNIP12_ATTRIBUTE_FORMAT)),
        }
    }

    Ok(args)
}

/// Parses the string argument from the attribute.
pub fn parse_string_arg(s: &str) -> Result<String, Diagnostic> {
    let Some(body) = s.strip_prefix('"').and_then(|s| s.strip_suffix('"')) else {
        return Err(Diagnostic::error(errors::INVALID_STRING_ARGUMENT));
    };
    if body.is_empty() {
        return Err(Diagnostic::error(errors::INVALID_STRING_ARGUMENT));
    }

    decode_escaped_string(body).ok_or_else(|| Diagnostic::error(errors::INVALID_STRING_ARGUMENT))
}

fn decode_escaped_string(s: &str) -> Option<String> {
    let mut decoded = String::with_capacity(s.len());
    let mut chars = s.chars();

    while let Some(ch) = chars.next() {
        if ch != '\\' {
            decoded.push(ch);
            continue;
        }

        let escaped = match chars.next()? {
            '"' => '"',
            '\\' => '\\',
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            '0' => '\0',
            _ => return None,
        };
        decoded.push(escaped);
    }

    Some(decoded)
}

/// Encodes a string as a JSON string literal, including the surrounding quotes.
fn encode_json_string(value: &str) -> String {
    let mut encoded = String::with_capacity(value.len() + 2);
    encoded.push('"');

    for ch in value.chars() {
        match ch {
            '"' => encoded.push_str("\\\""),
            '\\' => encoded.push_str("\\\\"),
            '\n' => encoded.push_str("\\n"),
            '\r' => encoded.push_str("\\r"),
            '\t' => encoded.push_str("\\t"),
            '\u{0}'..='\u{1f}' => encoded.push_str(&format!("\\u{:04x}", ch as u32)),
            _ => encoded.push(ch),
        }
    }

    encoded.push('"');
    encoded
}

/// Returns the enum compliant string representation of a tuple for the encoded type.
///
/// If the input is not a tuple, it returns the input itself.
///
/// Example:
/// ```
/// let encoded_type = maybe_tuple("(felt252, felt252, ClassHash, NftId)").unwrap();
/// assert_eq!(encoded_type, "\"felt252\",\"felt252\",\"ClassHash\",\"NftId\"");
/// ```
fn maybe_tuple(s: &str) -> Result<String, Diagnostic> {
    if s.starts_with("(") && s.ends_with(")") {
        let types = split_types(&s[1..s.len() - 1])
            .ok_or_else(|| Diagnostic::error(errors::INVALID_SNIP12_TYPE(s)))?;
        Ok(types
            .iter()
            .map(|s| format!("\"{}\"", s.trim()))
            .collect::<Vec<_>>()
            .join(","))
    } else {
        Ok(format!("\"{s}\""))
    }
}

#[cfg(test)]
mod tests {
    use super::{encode_json_string, parse_snip12_args, parse_string_arg};

    #[test]
    fn rejects_duplicate_snip12_name_argument() {
        assert!(parse_snip12_args(r#"(name: "first", name: "second")"#).is_err());
    }

    #[test]
    fn rejects_duplicate_snip12_kind_argument() {
        assert!(parse_snip12_args(r#"(kind: "felt252", kind: "u128")"#).is_err());
    }

    #[test]
    fn accepts_distinct_snip12_arguments() {
        let args = parse_snip12_args(r#"(name: "value", kind: "felt252")"#).unwrap();

        assert_eq!(args.name, "value");
        assert_eq!(args.kind, "felt252");
    }

    #[test]
    fn encodes_json_string() {
        assert_eq!(
            encode_json_string("quote\" slash\\ newline\n nul\0 unit\u{1f}"),
            r#""quote\" slash\\ newline\n nul\u0000 unit\u001f""#
        );
    }

    #[test]
    fn parses_plain_string_arg() {
        assert_eq!(parse_string_arg(r#""example""#).unwrap(), "example");
    }

    #[test]
    fn decodes_escaped_string_arg() {
        assert_eq!(
            parse_string_arg(r#""example\"quote""#).unwrap(),
            "example\"quote"
        );
        assert_eq!(
            parse_string_arg(r#""example\\path""#).unwrap(),
            "example\\path"
        );
    }

    #[test]
    fn rejects_invalid_string_arg() {
        assert!(parse_string_arg(r#""""#).is_err());
        assert!(parse_string_arg("example").is_err());
        assert!(parse_string_arg(r#""example\q""#).is_err());
    }
}
