//! Types for the type hash derive macro as defined in the SNIP-12.
//!
//! There are three kinds of types:
//!
//! 1. Basic types: defined in the spec for a given revision. Ex: felt, ClassHash, timestamp, u128...
//! 2. Preset types: they are structs defined in the spec. Ex: TokenAmount, NftId, u256. They also depend on the revision used.
//! 3. User defined types: The ones in the "types" field of the request. They also include the domain separator (Ex. StarknetDomain)

use cairo_lang_macro::Diagnostic;

use super::diagnostics::errors;

/// The different types of types as defined in the SNIP-12.
#[derive(Debug)]
pub enum S12Type {
    Basic(BasicType),
    Preset(PresetType),
    UserDefined(UserDefinedType),
}

/// The different basic types as defined in the SNIP-12.
#[derive(Debug)]
pub enum BasicType {
    Felt,
    ShortString,
    ClassHash,
    ContractAddress,
    Timestamp,
    Selector,
    U128,
    I128,
}

/// The different preset types as defined in the SNIP-12.
#[derive(Debug)]
pub enum PresetType {
    TokenAmount,
    NftId,
    U256,
}

/// The different user defined types as defined in the SNIP-12.
///
/// They include the domain separator.
#[derive(Debug)]
pub enum UserDefinedType {
    StarknetDomain,
    Custom(String),
}

impl S12Type {
    /// Creates a S12Type from a String
    pub fn from_str(s: &str) -> Option<S12Type> {
        match s {
            // Check empty string
            "" => return None,

            // Check basic types
            "felt252" => Some(S12Type::Basic(BasicType::Felt)),
            "shortstring" => Some(S12Type::Basic(BasicType::ShortString)),
            "ClassHash" => Some(S12Type::Basic(BasicType::ClassHash)),
            "ContractAddress" => Some(S12Type::Basic(BasicType::ContractAddress)),
            "timestamp" => Some(S12Type::Basic(BasicType::Timestamp)),
            "selector" => Some(S12Type::Basic(BasicType::Selector)),
            "u128" => Some(S12Type::Basic(BasicType::U128)),
            "i128" => Some(S12Type::Basic(BasicType::I128)),

            // Check preset types
            "TokenAmount" => Some(S12Type::Preset(PresetType::TokenAmount)),
            "NftId" => Some(S12Type::Preset(PresetType::NftId)),
            "u256" => Some(S12Type::Preset(PresetType::U256)),

            // Check user defined types
            "StarknetDomain" => Some(S12Type::UserDefined(UserDefinedType::StarknetDomain)),

            // Custom type
            _ => Some(S12Type::UserDefined(UserDefinedType::Custom(s.to_string()))),
        }
    }

    /// Returns the SNIP-12 type name for the S12Type.
    ///
    /// Example:
    /// ```
    /// let type_hash = S12Type::from_str("felt252").unwrap();
    /// assert_eq!(type_hash.get_snip12_type_name().unwrap(), "felt");
    /// ```
    pub fn get_snip12_type_name(&self) -> Result<String, Diagnostic> {
        match self {
            S12Type::Basic(basic_type) => basic_type.get_snip12_type_name(),
            S12Type::Preset(preset_type) => preset_type.get_snip12_type_name(),
            S12Type::UserDefined(user_defined_type) => user_defined_type.get_snip12_type_name(),
        }
    }

    /// Returns the encoded type for the S12Type.
    ///
    /// If the type is not an object/enum meaning it's a basic type, it returns an empty string.
    ///
    /// Example:
    /// ```
    /// let type_hash = S12Type::from_str("u256").unwrap();
    /// assert_eq!(type_hash.get_encoded_type().unwrap(), "\"u256\"(\"low\":\"u128\",\"high\":\"u128\")");
    /// ```
    pub fn get_encoded_ref_type(&self) -> Result<String, Diagnostic> {
        match self {
            S12Type::Basic(basic_type) => basic_type.get_encoded_ref_type(),
            S12Type::Preset(preset_type) => preset_type.get_encoded_ref_type(),
            S12Type::UserDefined(user_defined_type) => user_defined_type.get_encoded_ref_type(),
        }
    }
}

impl BasicType {
    /// Returns the SNIP-12 type name for the BasicType.
    pub fn get_snip12_type_name(&self) -> Result<String, Diagnostic> {
        match self {
            BasicType::Felt => Ok("felt".to_string()),
            BasicType::ShortString => Ok("shortstring".to_string()),
            BasicType::ClassHash => Ok("ClassHash".to_string()),
            BasicType::ContractAddress => Ok("ContractAddress".to_string()),
            BasicType::Timestamp => Ok("timestamp".to_string()),
            BasicType::Selector => Ok("selector".to_string()),
            BasicType::U128 => Ok("u128".to_string()),
            BasicType::I128 => Ok("i128".to_string()),
        }
    }

    /// Returns the encoded type for the BasicType.
    ///
    /// NOTE: since basic types are not objects/enums, they don't need a referenced encoded type.
    pub fn get_encoded_ref_type(&self) -> Result<String, Diagnostic> {
        match self {
            BasicType::Felt => Ok(String::new()),
            BasicType::ShortString => Ok(String::new()),
            BasicType::ClassHash => Ok(String::new()),
            BasicType::ContractAddress => Ok(String::new()),
            BasicType::Timestamp => Ok(String::new()),
            BasicType::Selector => Ok(String::new()),
            BasicType::U128 => Ok(String::new()),
            BasicType::I128 => Ok(String::new()),
        }
    }
}

impl PresetType {
    /// Returns the SNIP-12 type name for the PresetType.
    pub fn get_snip12_type_name(&self) -> Result<String, Diagnostic> {
        match self {
            PresetType::TokenAmount => Ok("TokenAmount".to_string()),
            PresetType::NftId => Ok("NftId".to_string()),
            PresetType::U256 => Ok("u256".to_string()),
        }
    }

    /// Returns the encoded type for the PresetType.
    pub fn get_encoded_ref_type(&self) -> Result<String, Diagnostic> {
        // TODO!: Add recursive types
        match self {
            PresetType::TokenAmount => Ok(
                "\"TokenAmount\"(\"token_address\":\"ContractAddress\",\"amount\":\"u256\")"
                    .to_string(),
            ),
            PresetType::NftId => Ok(
                "\"NftId\"(\"collection_address\":\"ContractAddress\",\"token_id\":\"u256\")"
                    .to_string(),
            ),
            PresetType::U256 => Ok("\"u256\"(\"low\":\"u128\",\"high\":\"u128\")".to_string()),
        }
    }
}

impl UserDefinedType {
    /// Returns the SNIP-12 type name for the UserDefinedType.
    pub fn get_snip12_type_name(&self) -> Result<String, Diagnostic> {
        match self {
            UserDefinedType::StarknetDomain => Ok("StarknetDomain".to_string()),
            UserDefinedType::Custom(name) => Ok(name.clone()),
        }
    }

    /// Returns the encoded type for the UserDefinedType.
    pub fn get_encoded_ref_type(&self) -> Result<String, Diagnostic> {
        match self {
            UserDefinedType::StarknetDomain => {
                Ok("\"StarknetDomain\"(\"name\":\"shortstring\",\"version\":\"shortstring\",\"chainId\":\"shortstring\",\"revision\":\"shortstring\")"
                    .to_string())
            }
            UserDefinedType::Custom(_) => Err(Diagnostic::error(errors::CUSTOM_TYPE_NOT_SUPPORTED)),
        }
    }
}
