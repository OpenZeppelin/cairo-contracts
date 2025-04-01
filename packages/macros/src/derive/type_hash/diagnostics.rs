//! List of errors and warnings for the type hash macro.

pub mod errors {
    /// Error when the type hash macro is applied to a struct containing a custom type.
    pub const CUSTOM_TYPE_NOT_SUPPORTED: &str = "Inner custom types are not supported yet.\n";
    /// Error when the type hash macro is applied to an empty block.
    pub const EMPTY_TYPE_FOUND: &str = "No valid type found in the input.\n";
    /// Error when the type hash macro is applied to a non-struct/enum type.
    pub const NOT_VALID_TYPE_FOR_DERIVE: &str = "Only structs and enums are supported.\n";
}
