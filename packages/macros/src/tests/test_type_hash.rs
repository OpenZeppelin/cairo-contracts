//! # Type Hash Macro Documentation
//!
//! The type hash macro provides functionality for generating type hashes for Starknet types.
//! This documentation is derived from the test cases.
//!
//! ## Basic Usage
//!
//! The macro can be applied to structs and enums:
//!
//! ```rust
//! #[type_hash]
//! pub struct MyType {
//!     pub field: felt252
//! }
//!
//! #[type_hash] 
//! pub enum MyEnum {
//!     Variant1,
//!     Variant2: felt252
//! }
//! ```
//!
//! ## Supported Types
//!
//! The following types are supported:
//!
//! ### Basic Types
//! - felt252
//! - ClassHash
//! - ContractAddress  
//! - u128
//! - i128
//!
//! ### Preset Types
//! - TokenAmount
//! - NftId
//! - u256
//! - StarknetDomain
//!
//! ### Collection Types
//! - Array<T>
//! - Span<T>
//! - Tuples (including empty tuples)
//!
//! ## Attributes
//!
//! The macro supports several attributes:
//!
//! ### Type Attributes
//! - `debug: bool` - Enables debug output
//! - `name: string` - Custom name for the type
//!
//! ### Field/Variant Attributes 
//! The `#[snip12]` attribute can be used on fields/variants with:
//!
//! - `kind: string` - Specify type kind (e.g. "shortstring", "timestamp", "selector")
//! - `name: string` - Custom name for the field/variant
//!
//! Example:
//! ```rust
//! #[type_hash(debug: true, name: "MyStruct")]
//! pub struct MyType {
//!     #[snip12(kind: "shortstring", name: "Field1")]
//!     pub field: felt252
//! }
//! ```
//!
//! ## Complex Types
//!
//! The macro handles complex nested types including:
//! - Nested tuples
//! - Arrays of tuples
//! - Arrays of arrays
//! - Combinations of collections and custom types
//!
//! ## Type Resolution
//!
//! The macro will:
//! - Resolve and include inner type definitions
//! - Handle duplicate type references
//! - Process custom type attributes
//!
//! For full examples, see the test cases below.

use cairo_lang_macro::TokenStream;
use indoc::indoc;
use insta::assert_snapshot;

use crate::type_hash::definition::type_hash_jgjpoopqerqnq as type_hash;

use super::common::format_proc_macro_result;

#[test]
fn test_empty_input() {
    let item = indoc!(
        "
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_empty_struct() {
    let item = indoc!(
        "
        pub struct MyType {}
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_empty_enum() {
    let item = indoc!(
        "
        pub enum MyEnum {}
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_snip12_attribute_empty() {
    let item = indoc!(
        "
        pub struct MyType {
            #[snip12()]
            pub name: felt252,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_basic_types() {
    // Basic types list:
    // - Felt
    // - ShortString
    // - ClassHash
    // - ContractAddress
    // - Timestamp
    // - Selector
    // - U128
    // - I128
    let item = indoc!(
        r#"
        pub struct MyType {
            pub name: felt252,
            #[snip12(kind: "shortstring")]
            pub version: felt252,
            pub class_hash: ClassHash,
            pub contract_address: ContractAddress,
            #[snip12(kind: "timestamp")]
            pub timestamp: u128,
            #[snip12(kind: "selector")]
            pub selector: felt252,
            pub u128_member: u128,
            pub i128_member: i128,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_basic_types_enum() {
    let item = indoc!(
        r#"
        pub enum MyEnum {
            Variant1: felt252,
            Variant2: ClassHash,
            Variant3: ContractAddress,
            Variant4: u128,
            Variant5: i128,
            #[snip12(kind: "shortstring")]
            Variant6: felt252,
            #[snip12(kind: "timestamp")]
            Variant7: u128,
            #[snip12(kind: "selector")]
            Variant8: felt252,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_preset_types() {
    // Preset types list:
    // - TokenAmount
    // - NftId
    // - U256
    let item = indoc!(
        "
        pub struct MyType {
            pub token_amount: TokenAmount,
            pub nft_id: NftId,
            pub u256: u256,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_preset_types_enum() {
    let item = indoc!(
        "
        pub enum MyEnum {
            Variant1: TokenAmount,
            Variant2: NftId,
            Variant3: u256,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}
#[test]
fn test_with_inner_starknet_domain() {
    let item = indoc!(
        "
        pub struct MyType {
            pub starknet_domain: StarknetDomain,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_inner_u256_type() {
    let item = indoc!(
        "
        pub struct MyType {
            // TokenAmount type contains u256, which should be resolved
            // and appended to the final type hash.
            pub token_amount: TokenAmount,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_inner_u256_type_enum() {
    let item = indoc!(
        "
        pub enum MyEnum {
            // TokenAmount type contains u256, which should be resolved
            // and appended to the final type hash.
            Variant1: TokenAmount,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_potential_duplicate_types() {
    let item = indoc!(
        "
        pub struct MyType {
            // TokenAmount type contains u256, which should be resolved
            // and appended to the final type hash.
            pub token_amount: TokenAmount,
            pub token_amount_2: TokenAmount,
            pub number: u256,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_potential_duplicate_types_enum() {
    let item = indoc!(
        "
        pub enum MyEnum {
            // TokenAmount type contains u256, which should be resolved
            // and appended to the final type hash.
            Variant1: TokenAmount,
            Variant2: TokenAmount,
            Variant3: u256,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_complex_struct_type() {
    let item = indoc!(
        r#"
        pub struct MyType {
            pub token_amount: TokenAmount,
            pub token_amount_2: TokenAmount,
            pub number: u256,
            #[snip12(kind: "shortstring")]
            pub version: felt252,
            pub class_hash: ClassHash,
            pub contract_address: ContractAddress,
            #[snip12(kind: "timestamp")]
            pub timestamp: u128,
            #[snip12(kind: "selector")]
            pub selector: felt252,
            pub u128_member: u128,
            pub i128_member: i128,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_complex_enum_type() {
    let item = indoc!(
        r#"
        pub enum MyEnum {
            Variant1: TokenAmount,
            Variant2: TokenAmount,
            Variant3: u256,
            #[snip12(kind: "shortstring")]
            Variant4: felt252,
            Variant5: ClassHash,
            Variant6: ContractAddress,
            #[snip12(kind: "timestamp")]
            Variant7: u128,
            #[snip12(kind: "selector")]
            Variant8: felt252,
            Variant9: u128,
            Variant10: i128,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_inner_custom_type() {
    let item = indoc!(
        "
        pub struct MyType {
            pub name: felt252,
            pub version: felt252,
            pub chain_id: felt252,
            pub revision: felt252,
            pub member: InnerCustomType,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_tuple() {
    let item = indoc!(
        "
        pub struct MyType {
            pub member: (felt252, felt252, ClassHash, NftId),
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_tuple_enum() {
    let item = indoc!(
        "
        pub enum MyEnum {
            Variant1: (felt252, felt252, ClassHash, NftId),
            Variant2: TokenAmount,
            Variant3: (ContractAddress,),
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_empty_tuple() {
    // This doesn't make sense, but it's a valid type.
    let item = indoc!(
        "
        pub struct MyType {
            pub member: (),
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_empty_tuple_enum() {
    let item = indoc!(
        "
        pub enum MyEnum {
            Variant1: TokenAmount,
            Variant2: (),
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_array() {
    let item = indoc!(
        "
        pub struct MyType {
            pub member1: Array<felt252>,
            pub member2: Array<TokenAmount>,
            pub member3: Array<ClassHash>,
            pub member4: Array<ContractAddress>,
            pub member5: Array<u128>,
            pub member6: Array<i128>,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_span() {
    let item = indoc!(
        "
        pub struct MyType {
            pub member1: Span<felt252>,
            pub member2: Span<TokenAmount>,
            pub member3: Span<ClassHash>,
            pub member4: Span<ContractAddress>,
            pub member5: Span<u128>,
            pub member6: Span<i128>,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_with_tuple_and_attribute() {
    let item = indoc!(
        r#"
        pub struct MyType {
            #[snip12(kind: "(shortstring, felt252, ClassHash, NftId)")]
            pub member: (felt252, felt252, ClassHash, NftId),
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_starknet_domain() {
    let item = indoc!(
        r#"
        pub struct StarknetDomain {
            #[snip12(kind: "shortstring")]
            pub name: felt252,
            #[snip12(kind: "shortstring")]
            pub version: felt252,
            #[snip12(kind: "shortstring")]
            pub chainId: felt252,
            #[snip12(kind: "shortstring")]
            pub revision: felt252,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_complex_struct_with_collection_types() {
    let item = indoc!(
        r#"
        pub struct MyType {
            pub member1: (felt252, felt252, ClassHash, NftId),
            pub member2: Array<TokenAmount>,
            pub member3: Span<ClassHash>,
            pub member4: (ContractAddress, TokenAmount),
            pub member5: Array<ContractAddress>,
            pub member6: (),
            #[snip12(kind: "(timestamp, shortstring)")]
            pub member7: (u128, felt252),
            pub member8: (ContractAddress,),
            pub member9: (TokenAmount, (felt252, ClassHash), NftId),
            pub member10: (Array<TokenAmount>, Array<ContractAddress>),
            pub member11: Array<(TokenAmount, ContractAddress, Array<felt252>)>,
            pub member12: Array<Array<(Array<TokenAmount>, Array<ContractAddress>, Array<felt252>)>>,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_complex_struct_with_collection_types_custom_names() {
    let item = indoc!(
        r#"
        pub struct MyType {
            #[snip12(name: "Member 1")]
            pub member1: (felt252, felt252, ClassHash, NftId),
            #[snip12(name: "Member 2")]
            pub member2: Array<TokenAmount>,
            #[snip12(name: "Member 3")]
            pub member3: Span<ClassHash>,
            #[snip12(name: "Member 4")]
            pub member4: (ContractAddress, TokenAmount),
            #[snip12(name: "Member 5")]
            pub member5: Array<ContractAddress>,
            #[snip12(name: "Member 6")]
            pub member6: (),
            #[snip12(name: "Member 7", kind: "(timestamp, shortstring)")]
            pub member7: (u128, felt252),
            #[snip12(name: "Member 8")]
            pub member8: (ContractAddress,),
            #[snip12(name: "Member 9")]
            pub member9: (TokenAmount, (felt252, ClassHash), NftId),
            #[snip12(name: "Member 10")]
            pub member10: (Array<TokenAmount>, Array<ContractAddress>),
            #[snip12(name: "Member 11")]
            pub member11: Array<(TokenAmount, ContractAddress, Array<felt252>)>,
            #[snip12(name: "Member 12")]
            pub member12: Array<Array<(Array<TokenAmount>, Array<ContractAddress>, Array<felt252>)>>,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_complex_enum_with_collection_types() {
    let item = indoc!(
        r#"
        pub enum MyEnum {
            Variant1: (felt252, felt252, ClassHash, NftId),
            Variant2: Array<TokenAmount>,
            Variant3: Span<ClassHash>,
            Variant4: (ContractAddress, TokenAmount),
            Variant5: Array<ContractAddress>,
            Variant6: (),
            #[snip12(kind: "(timestamp, shortstring)")]
            Variant7: (u128, felt252),
            Variant8: (ContractAddress,),
            Variant9: (TokenAmount, (felt252, ClassHash), NftId),
            Variant10: (Array<TokenAmount>, Array<ContractAddress>),
            Variant11: Array<(TokenAmount, ContractAddress, Array<felt252>)>,
            Variant12: Array<Array<(Array<TokenAmount>, Array<ContractAddress>, Array<felt252>)>>,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_complex_enum_with_collection_types_custom_names() {
    let item = indoc!(
        r#"
        pub enum MyEnum {
            #[snip12(name: "Variant 1")]
            Variant1: (felt252, felt252, ClassHash, NftId),
            #[snip12(name: "Variant 2")]
            Variant2: Array<TokenAmount>,
            #[snip12(name: "Variant 3")]
            Variant3: Span<ClassHash>,
            #[snip12(name: "Variant 4")]
            Variant4: (ContractAddress, TokenAmount),
            #[snip12(name: "Variant 5")]
            Variant5: Array<ContractAddress>,
            #[snip12(name: "Variant 6")]
            Variant6: (),
            #[snip12(name: "Variant 7", kind: "(timestamp, shortstring)")]
            Variant7: (u128, felt252),
            #[snip12(name: "Variant 8")]
            Variant8: (ContractAddress,),
            #[snip12(name: "Variant 9")]
            Variant9: (TokenAmount, (felt252, ClassHash), NftId),
            #[snip12(name: "Variant 10")]
            Variant10: (Array<TokenAmount>, Array<ContractAddress>),
            #[snip12(name: "Variant 11")]
            Variant11: Array<(TokenAmount, ContractAddress, Array<felt252>)>,
            #[snip12(name: "Variant 12")]
            Variant12: Array<Array<(Array<TokenAmount>, Array<ContractAddress>, Array<felt252>)>>,
        }
        "#
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_name_attribute() {
    let item = indoc!(
        r#"
        pub enum MyEnum {
            #[snip12(name: "Variant 1")]
            Variant1: (felt252, felt252, ClassHash, NftId),
            #[snip12(name: "Variant 2")]
            Variant2: Array<TokenAmount>,
            #[snip12(name: "Variant 3")]
            Variant3: Span<ClassHash>,
            #[snip12(name: "Variant 4")]
            Variant4: (ContractAddress, TokenAmount),
            #[snip12(name: "Variant 5")]
            Variant5: Array<ContractAddress>,
        }
        "#
    );
    let attr_stream = r#"(name: "My Enum")"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_debug_attribute() {
    let item = indoc!(
        "
        pub struct MyType {
            pub member: felt252,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_invalid_type_hash_attribute() {
    let item = indoc!(
        "
        pub struct MyType {
            pub member: felt252,
        }
        "
    );
    let attr_stream = r#"(other: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

#[test]
fn test_enum_without_explicit_variant_type() {
    let item = indoc!(
        "
        pub enum MyEnum {
            Variant1,
            Variant2,
        }
        "
    );
    let attr_stream = r#"(debug: true)"#;
    let result = get_string_result(item, attr_stream);
    assert_snapshot!(result);
}

fn get_string_result(item: &str, attr_stream: &str) -> String {
    let attr_stream = TokenStream::new(attr_stream.to_string());
    let item = TokenStream::new(item.to_string());
    let raw_result = type_hash(attr_stream, item);
    format_proc_macro_result(raw_result)
}
