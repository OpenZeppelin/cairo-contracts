//! Parser utilities for the type hash macro.

use std::collections::HashSet;

use cairo_lang_macro::Diagnostic;
use cairo_lang_plugins::plugins::utils::{PluginTypeInfo, TypeVariant};
use cairo_lang_syntax::node::TypedSyntaxNode;
use cairo_lang_syntax::{node::ast::Attribute, node::db::SyntaxGroup};

use crate::attribute::common::args::split_top_level_args;

use super::definition::TypeHashArgs;
use super::diagnostics::errors;
use super::types::{split_types, InnerType, S12Type};

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
                let s12_type = S12Type::from_str(&type_input);

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
        let mut encoded_type = if args.name.is_empty() {
            format!("\"{}\"(", self.plugin_type_info.name)
        } else {
            format!("\"{}\"(", args.name)
        };
        for result in members_types {
            let (name, s12_type) = result?;
            let type_name = s12_type.get_snip12_type_name()?;

            // Format the member depending on the type variant
            match self.plugin_type_info.type_variant {
                TypeVariant::Struct => {
                    encoded_type.push_str(&format!("\"{name}\":\"{type_name}\","))
                }
                TypeVariant::Enum => {
                    let tuple = maybe_tuple(&type_name)?;
                    encoded_type.push_str(&format!("\"{}\"({}),", name, tuple))
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
    for attribute in attributes {
        let attribute_text = attribute.as_syntax_node().get_text_without_trivia(db);
        let Some(arguments) = snip12_attribute_arguments(attribute_text.long(db).as_str()) else {
            continue;
        };
        return parse_snip12_args(arguments);
    }
    Ok(Snip12Args {
        name: String::new(),
        kind: String::new(),
    })
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

    // If the attribute is empty, return the default args
    let s = s.trim();
    if s.is_empty() || s == "()" {
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
            "name" => args.name = parse_string_arg(value.trim())?,
            "kind" => args.kind = parse_string_arg(value.trim())?,
            _ => return Err(Diagnostic::error(errors::INVALID_SNIP12_ATTRIBUTE_FORMAT)),
        }
    }

    Ok(args)
}

/// Parses the string argument from the attribute.
pub fn parse_string_arg(s: &str) -> Result<String, Diagnostic> {
    if s.len() >= 3 && s.starts_with("\"") && s.ends_with("\"") {
        // Remove the quotes
        Ok(s[1..s.len() - 1].to_string())
    } else {
        Err(Diagnostic::error(errors::INVALID_STRING_ARGUMENT))
    }
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
