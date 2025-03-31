use crate::type_hash::type_hash_jgjpoopqerqnq as type_hash;
use cairo_lang_macro::TokenStream;
use indoc::indoc;
use insta::assert_snapshot;

use super::common::format_proc_macro_result;

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
        #[derive(TypeHash)]
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
fn test_with_inner_custom_type() {
    let item = indoc!(
        "
        #[derive(TypeHash)]
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
