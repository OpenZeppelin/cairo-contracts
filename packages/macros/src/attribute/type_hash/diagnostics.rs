//! List of errors and warnings for the type hash macro.

#[allow(non_snake_case)]
pub mod errors {
    /// Error when the type hash macro is applied to a struct containing a custom type.
    pub const CUSTOM_TYPE_NOT_SUPPORTED: &str = "Inner custom types are not supported yet.\n";
    /// Error when the type hash macro is applied to an empty block.
    pub const EMPTY_TYPE_FOUND: &str = "No valid type found in the input.\n";
    /// Error when the type hash macro is applied to a non-struct/enum type.
    pub const NOT_VALID_TYPE_TO_DECORATE: &str = "Only structs and enums are supported.\n";
    /// Error when the format of the type_hash attribute is invalid.
    pub const INVALID_TYPE_HASH_ATTRIBUTE_FORMAT: &str =
        "Invalid format for the type_hash attribute. The only valid arguments are: name, debug.\n";
    /// Error when the format of the snip12 attribute is invalid.
    pub const INVALID_SNIP12_ATTRIBUTE_FORMAT: &str =
        "Invalid format for the snip12 attribute. The only valid arguments are: name, kind.\n";
    /// Error when a member has more than one snip12 attribute.
    pub const MULTIPLE_SNIP12_ATTRIBUTES: &str =
        "Only one snip12 attribute can be applied to a member.\n";
    /// Error when the string argument is invalid.
    pub const INVALID_STRING_ARGUMENT: &str =
        "Invalid string argument. Expected a non-empty string between double quotes.\n";
    /// Error when a SNIP-12 type override cannot be parsed.
    pub fn INVALID_SNIP12_TYPE(ty: &str) -> String {
        format!("Invalid SNIP-12 type: {ty}.\n")
    }
    /// Error when a user-defined primary type reuses a SNIP-12 reserved name.
    pub fn RESERVED_SNIP12_TYPE_NAME(name: &str) -> String {
        format!("SNIP-12 type name `{name}` is reserved and cannot be used as a primary type.\n")
    }
}
