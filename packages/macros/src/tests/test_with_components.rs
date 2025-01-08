use crate::with_components::with_components_avevetedp5blk as with_components;
use cairo_lang_macro::TokenStream;
use indoc::{formatdoc, indoc};
use insta::assert_snapshot;

#[test]
fn test_with_erc20() {
    let attribute = "(ERC20)";
    let item = indoc!(
        "
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
                self.erc20.initializer(\"MyToken\", \"MTK\");
            }
        }
        "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_erc20_no_initializer() {
    let attribute = "(ERC20)";
    let item = indoc!(
        "
      #[starknet::contract]
      pub mod MyToken {
          use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
          use starknet::ContractAddress;

          #[storage]
          pub struct Storage {}

          #[constructor]
          fn constructor(ref self: ContractState) {
          }
      }
      "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_ownable() {
    let attribute = "(Ownable)";
    let item = indoc!(
        "
        #[starknet::contract]
        pub mod Owned {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, owner: ContractAddress) {
                self.ownable.initializer(owner);
            }
        }
        "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_ownable_no_initializer() {
    let attribute = "(Ownable)";
    let item = indoc!(
        "
      #[starknet::contract]
      pub mod Owned {
          use starknet::ContractAddress;

          #[storage]
          pub struct Storage {}

          #[constructor]
          fn constructor(ref self: ContractState) {
          }
      }
      "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_two_components() {
    let attribute = "(ERC20, Ownable)";
    let item = indoc!(
        "
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, owner: ContractAddress) {
                self.ownable.initializer(owner);
                self.erc20.initializer(\"MyToken\", \"MTK\");
            }
        }
        "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_two_components_no_initializer() {
    let attribute = "(ERC20, Ownable)";
    let item = indoc!(
        "
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState) {
            }
        }
        "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_two_components_no_constructor() {
    let attribute = "(ERC20, Ownable)";
    let item = indoc!(
        "
        #[starknet::contract]
        pub mod MyToken {
            use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}
        }
        "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_no_contract_attribute() {
    let attribute = "(Ownable)";
    let item = indoc!(
        "
        pub mod Owned {
            use starknet::ContractAddress;

            #[storage]
            pub struct Storage {}

            #[constructor]
            fn constructor(ref self: ContractState, owner: ContractAddress) {
                self.ownable.initializer(owner);
            }
        }
        "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

#[test]
fn test_with_no_body() {
    let attribute = "(ERC20, Ownable)";
    let item = indoc!(
        "
        pub mod MyToken;
        "
    );
    let result = get_string_result(attribute, item);
    assert_snapshot!(result);
}

//
// Helpers
//

/// Returns a string representation of the result of the macro expansion,
/// including the token stream, diagnostics and aux data.
fn get_string_result(attribute: &str, item: &str) -> String {
    let attribute_stream = TokenStream::new(attribute.to_string());
    let item_stream = TokenStream::new(item.to_string());
    let raw_result = with_components(attribute_stream, item_stream);
    let none = "None";

    let mut token_stream = raw_result.token_stream.to_string();
    let mut diagnostics = String::new();
    for d in raw_result.diagnostics {
        diagnostics += format!("====\n{:?}: {}====", d.severity, d.message).as_str();
    }

    if token_stream.is_empty() {
        token_stream = none.to_string();
    }
    if diagnostics.is_empty() {
        diagnostics = none.to_string();
    }

    formatdoc! {
        "
        TokenStream:

        {}

        Diagnostics:

        {}

        AuxData:

        {:?}
        ",
        token_stream, diagnostics, raw_result.aux_data
    }
}
