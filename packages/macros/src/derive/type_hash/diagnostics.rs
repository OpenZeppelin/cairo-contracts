//! List of errors and warnings for the type hash macro.

pub mod errors {
    /// Error when the type hash macro is applied to a struct containing a custom type.
    pub const CUSTOM_TYPE_NOT_SUPPORTED: &str = "Inner custom types are not supported yet.\n";
}
