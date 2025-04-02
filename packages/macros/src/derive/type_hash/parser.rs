//! Parser utilities for the type hash macro.

use std::collections::HashSet;

use cairo_lang_macro::Diagnostic;
use cairo_lang_plugins::plugins::utils::{PluginTypeInfo, TypeVariant};
use cairo_lang_syntax::node::TypedSyntaxNode;
use cairo_lang_syntax::{node::ast::Attribute, node::db::SyntaxGroup};
use regex::Regex;

use super::definition::TypeHashConfig;
use super::types::{split_types, InnerType, S12Type};

const SNIP12_TYPE_ATTRIBUTE: &str = "snip12";

/// The parser for the type hash macro.
///
/// It parses the members of the struct or enum and maintains a list of types including referenced objects/enums.
pub struct TypeHashParser<'a> {
    /// The plugin type info object.
    plugin_type_info: &'a PluginTypeInfo,
    /// Quick lookup for already processed types.
    is_type_processed: HashSet<String>,
    /// The encode type of the objects/enums referenced in the input that have already been processed.
    /// HashSet is used to avoid duplicates.
    processed_ref_encoded_types: HashSet<String>,
}

impl<'a> TypeHashParser<'a> {
    /// Creates a new parser for the type hash macro from a plugin type info object.
    pub fn new(plugin_type_info: &'a PluginTypeInfo) -> Self {
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
        db: &dyn SyntaxGroup,
        config: &TypeHashConfig,
    ) -> Result<String, Diagnostic> {
        // 1. Get the members types real values from mapping and attributes
        let members_types = self
            .plugin_type_info
            .members_info
            .iter()
            .map(|member| {
                let attributes = member.attributes.elements(db);
                let (attr_name, attr_type) = get_name_and_type_from_attributes(db, &attributes);

                // If there is an attribute, use it, otherwise use the type from the member
                let s12_type = if let Some(attr_type) = attr_type {
                    S12Type::from_str(&attr_type)
                } else {
                    S12Type::from_str(&member.ty)
                };

                // If there is an attribute, use it, otherwise use the name from the member
                let s12_name = if let Some(attr_name) = attr_name {
                    attr_name
                } else {
                    member.name.to_string()
                };

                // Unwrapping should be safe here since attr types must not be empty
                (s12_name, s12_type.unwrap())
            })
            .collect::<Vec<(String, S12Type)>>();

        // 2. Build the string representation
        let mut encoded_type = if config.name.is_empty() {
            format!("\"{}\"(", self.plugin_type_info.name)
        } else {
            format!("\"{}\"(", config.name)
        };
        for (name, s12_type) in members_types {
            let type_name = s12_type.get_snip12_type_name()?;

            // Format the member depending on the type variant
            match self.plugin_type_info.type_variant {
                TypeVariant::Struct => {
                    encoded_type.push_str(&format!("\"{}\":\"{}\",", name, type_name))
                }
                TypeVariant::Enum => {
                    encoded_type.push_str(&format!("\"{}\"({}),", name, maybe_tuple(&type_name)))
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
) -> (Option<String>, Option<String>) {
    let re = Regex::new(&format!(r"^\#\[{SNIP12_TYPE_ATTRIBUTE}\((.*)\)\]$")).unwrap();

    for attribute in attributes {
        let attribute_text = attribute.as_syntax_node().get_text_without_trivia(db);
        if re.is_match(&attribute_text) {
            let captures = re.captures(&attribute_text);
            if let Some(captures) = captures {
                return parse_snip12_attribute_arguments(&captures[1]);
            }
        }
    }
    (None, None)
}

fn parse_snip12_attribute_arguments(arguments: &str) -> (Option<String>, Option<String>) {
    let re1 = Regex::new(r#"^name: "(.*)", kind: "(.*)"$"#).unwrap();
    let re2 = Regex::new(r#"^kind: "(.*)", name: "(.*)"$"#).unwrap();
    let re3 = Regex::new(r#"^name: "(.*)"$"#).unwrap();
    let re4 = Regex::new(r#"^kind: "(.*)"$"#).unwrap();

    if re1.is_match(arguments) {
        let captures = re1.captures(arguments);
        if let Some(captures) = captures {
            return (Some(captures[1].to_string()), Some(captures[2].to_string()));
        }
    } else if re2.is_match(arguments) {
        let captures = re2.captures(arguments);
        if let Some(captures) = captures {
            return (Some(captures[2].to_string()), Some(captures[1].to_string()));
        }
    } else if re3.is_match(arguments) {
        let captures = re3.captures(arguments);
        if let Some(captures) = captures {
            return (Some(captures[1].to_string()), None);
        }
    } else if re4.is_match(arguments) {
        let captures = re4.captures(arguments);
        if let Some(captures) = captures {
            return (None, Some(captures[1].to_string()));
        }
    }
    (None, None)
}

/// Returns the enum compliant string representation of a tuple for the encoded type.
///
/// If the input is not a tuple, it returns the input itself.
///
/// Example:
/// ```
/// let encoded_type = maybe_tuple("(felt252, felt252, ClassHash, NftId)");
/// assert_eq!(encoded_type, "\"felt252\",\"felt252\",\"ClassHash\",\"NftId\"");
/// ```
fn maybe_tuple(s: &str) -> String {
    if s.starts_with("(") && s.ends_with(")") {
        split_types(&s[1..s.len() - 1])
            .iter()
            .map(|s| format!("\"{}\"", s.trim()))
            .collect::<Vec<_>>()
            .join(",")
    } else {
        format!("\"{}\"", s)
    }
}
