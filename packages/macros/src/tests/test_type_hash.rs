use crate::type_hash::type_hash_jgjpoopqerqnq as type_hash;
use cairo_lang_macro::TokenStream;
use indoc::indoc;
use insta::assert_snapshot;

use super::common::format_proc_macro_result;

#[test]
fn test_empty_input() {
    let item = indoc!(
        "
        "
    );
    let result = get_string_result(item);
    assert_snapshot!(result);
}

#[test]
fn test_empty_struct() {
    let item = indoc!(
        "
        pub struct MyType {}
        "
    );
    let result = get_string_result(item);
    assert_snapshot!(result);
}

#[test]
fn test_empty_enum() {
    let item = indoc!(
        "
        pub enum MyEnum {}
        "
    );
    let result = get_string_result(item);
    assert_snapshot!(result);
}

#[test]
fn test_snip12_type_attribute_empty() {
    let item = indoc!(
        "
        pub struct MyType {
            #[snip12_type()]
            pub name: felt252,
        }
        "
    );
    let result = get_string_result(item);
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
        "
        pub struct MyType {
            pub name: felt252,
            #[snip12_type(shortstring)]
            pub version: felt252,
            pub class_hash: ClassHash,
            pub contract_address: ContractAddress,
            #[snip12_type(timestamp)]
            pub timestamp: u128,
            #[snip12_type(selector)]
            pub selector: felt252,
            pub u128_member: u128,
            pub i128_member: i128,
        }
        "
    );
    let result = get_string_result(item);
    assert_snapshot!(result);
}

#[test]
fn test_basic_types_enum() {
    let item = indoc!(
        "
        pub enum MyEnum {
            Variant1: felt252,
            Variant2: ClassHash,
            Variant3: ContractAddress,
            Variant4: u128,
            Variant5: i128,
            #[snip12_type(shortstring)]
            Variant6: felt252,
            #[snip12_type(timestamp)]
            Variant7: u128,
            #[snip12_type(selector)]
            Variant8: felt252,
        }
        "
    );
    let result = get_string_result(item);
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
    let result = get_string_result(item);
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
    let result = get_string_result(item);
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
    let result = get_string_result(item);
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
    let result = get_string_result(item);
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
    let result = get_string_result(item);
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
    let result = get_string_result(item);
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
    let result = get_string_result(item);
    assert_snapshot!(result);
}

#[test]
fn test_complex_struct_type() {
    let item = indoc!(
        "
        pub struct MyType {
            pub token_amount: TokenAmount,
            pub token_amount_2: TokenAmount,
            pub number: u256,
            #[snip12_type(shortstring)]
            pub version: felt252,
            pub class_hash: ClassHash,
            pub contract_address: ContractAddress,
            #[snip12_type(timestamp)]
            pub timestamp: u128,
            #[snip12_type(selector)]
            pub selector: felt252,
            pub u128_member: u128,
            pub i128_member: i128,
        }
        "
    );
    let result = get_string_result(item);
    assert_snapshot!(result);
}

#[test]
fn test_complex_enum_type() {
    let item = indoc!(
        "
        pub enum MyEnum {
            Variant1: TokenAmount,
            Variant2: TokenAmount,
            Variant3: u256,
            #[snip12_type(shortstring)]
            Variant4: felt252,
            Variant5: ClassHash,
            Variant6: ContractAddress,
            #[snip12_type(timestamp)]
            Variant7: u128,
            #[snip12_type(selector)]
            Variant8: felt252,
            Variant9: u128,
            Variant10: i128,
        }
        "
    );
    let result = get_string_result(item);
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
    let result = get_string_result(item);
    assert_snapshot!(result);
}

#[test]
fn test_starknet_domain() {
    let item = indoc!(
        "
        pub struct StarknetDomain {
            #[snip12_type(shortstring)]
            pub name: felt252,
            #[snip12_type(shortstring)]
            pub version: felt252,
            #[snip12_type(shortstring)]
            pub chainId: felt252,
            #[snip12_type(shortstring)]
            pub revision: felt252,
        }
        "
    );
    let result = get_string_result(item);
    assert_snapshot!(result);
}

fn get_string_result(item: &str) -> String {
    let item = TokenStream::new(item.to_string());
    let raw_result = type_hash(item);
    format_proc_macro_result(raw_result)
}
