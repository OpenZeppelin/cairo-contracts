//! Parser utilities for the type hash macro.

use std::collections::HashMap;

use cairo_lang_macro::Diagnostic;
use cairo_lang_plugins::plugins::utils::PluginTypeInfo;
use cairo_lang_syntax::node::TypedSyntaxNode;
use cairo_lang_syntax::{node::ast::Attribute, node::db::SyntaxGroup};
use regex::Regex;

use super::types::S12Type;

const SNIP12_TYPE_ATTRIBUTE: &str = "snip12_type";

/// The parser for the type hash macro.
///
/// It parses the members of the struct or enum and maintains a list of types including referenced objects/enums.
pub struct TypeHashParser<'a> {
    /// The plugin type info object.
    plugin_type_info: &'a PluginTypeInfo,
    /// Quick lookup for already processed types.
    is_type_processed: HashMap<String, bool>,
    /// The objects/enums referenced in the input that have already been processed.
    processed_ref_types: Vec<ProcessedType>,
}

/// The reference objects/enums already processed.
struct ProcessedType {
    encoded_type: String,
}

impl<'a> TypeHashParser<'a> {
    /// Creates a new parser for the type hash macro from a plugin type info object.
    pub fn new(plugin_type_info: &'a PluginTypeInfo) -> Self {
        let is_type_processed = HashMap::new();
        let processed_ref_types = Vec::new();

        Self {
            plugin_type_info,
            is_type_processed,
            processed_ref_types,
        }
    }

    /// Parses the object/enum and returns the encoded type.
    pub fn parse(&mut self, db: &dyn SyntaxGroup) -> Result<String, Diagnostic> {
        // 1. Get the members types real values from mapping and attributes
        let members_types = self
            .plugin_type_info
            .members_info
            .iter()
            .map(|member| {
                let attributes = member.attributes.elements(db);
                let attr_type = get_type_from_attributes(db, &attributes);

                // If there is an attribute, use it, otherwise use the type from the member
                let s12_type = if let Some(attr_type) = attr_type {
                    S12Type::from_str(&attr_type)
                } else {
                    S12Type::from_str(&member.ty)
                };
                // Unwrapping should be safe here since attr types must not be empty
                (member.name.as_str(), s12_type.unwrap())
            })
            .collect::<Vec<(&str, S12Type)>>();

        // 2. Build the string representation
        let mut encoded_type = format!("\"{}\"(", self.plugin_type_info.name);
        for (name, s12_type) in members_types {
            let type_name = s12_type.get_snip12_type_name()?;
            encoded_type.push_str(&format!("\"{}\":\"{}\",", name, type_name));

            if !self.is_type_processed.contains_key(&type_name) {
                let encoded_type = s12_type.get_encoded_ref_type()?;
                self.processed_ref_types
                    .push(ProcessedType { encoded_type });
                self.is_type_processed.insert(type_name, true);
            }
        }
        if encoded_type.ends_with(",") {
            encoded_type.pop();
        }
        encoded_type.push_str(")");

        // TODO!: Check recursive types and avoid duplicates
        self.processed_ref_types
            .sort_by_key(|p| p.encoded_type.clone());
        for processed_type in self.processed_ref_types.iter() {
            encoded_type.push_str(&processed_type.encoded_type);
        }

        // 3. Return the encoded type
        Ok(encoded_type)
    }
}

/// Gets the type from the attributes.
///
/// The expected attribute is of the form:
/// ```
/// #[snip12_type(<type>)]
/// ```
fn get_type_from_attributes(db: &dyn SyntaxGroup, attributes: &[Attribute]) -> Option<String> {
    let re = Regex::new(&format!(r"^\#\[{SNIP12_TYPE_ATTRIBUTE}\((.*)\)\]$")).unwrap();

    for attribute in attributes {
        let attribute_text = attribute.as_syntax_node().get_text_without_trivia(db);
        if re.is_match(&attribute_text) {
            let captures = re.captures(&attribute_text);
            if let Some(captures) = captures {
                let type_name = captures[1].to_string();
                if type_name.is_empty() {
                    // This should never happen since there must be a check in the snip_12 attribute macro
                    panic!("Type name is empty");
                }
                return Some(type_name);
            }
        }
    }
    None
}
