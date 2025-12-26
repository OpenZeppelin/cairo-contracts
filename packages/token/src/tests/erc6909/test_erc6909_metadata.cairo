use openzeppelin_interfaces::erc6909::IERC6909_METADATA_ID;
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::mocks::erc6909::ERC6909MetadataMock;
use openzeppelin_testing::constants::{DECIMALS, NAME, OWNER, SYMBOL, TOKEN_ID, ZERO};
use starknet::ContractAddress;
use crate::erc6909::extensions::erc6909_metadata::ERC6909MetadataComponent;
use crate::erc6909::extensions::erc6909_metadata::ERC6909MetadataComponent::{
    ERC6909MetadataImpl, InternalImpl,
};

type ComponentState = ERC6909MetadataComponent::ComponentState<ERC6909MetadataMock::ContractState>;

fn CONTRACT_STATE() -> ERC6909MetadataMock::ContractState {
    ERC6909MetadataMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC6909MetadataComponent::component_state_for_testing()
}

fn ALT_NAME() -> ByteArray {
    "ALT_NAME"
}
fn ALT_SYMBOL() -> ByteArray {
    "ALT_SYMBOL"
}
const ALT_DECIMALS: u8 = 6;

#[test]
fn test_initializer_registers_interface() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer();

    assert!(mock_state.supports_interface(IERC6909_METADATA_ID));
    assert!(mock_state.supports_interface(ISRC5_ID));
}

#[test]
fn test_default_getters_are_empty_or_zero() {
    let state = COMPONENT_STATE();

    let empty: ByteArray = "";
    assert_eq!(state.name(TOKEN_ID), empty);
    assert_eq!(state.symbol(TOKEN_ID), empty);
    assert_eq!(state.decimals(TOKEN_ID), 0);
}

#[test]
fn test__set_token_metadata_sets_values() {
    let mut state = COMPONENT_STATE();

    state._set_token_metadata(TOKEN_ID, NAME(), SYMBOL(), DECIMALS);

    assert_eq!(state.name(TOKEN_ID), NAME());
    assert_eq!(state.symbol(TOKEN_ID), SYMBOL());
    assert_eq!(state.decimals(TOKEN_ID), DECIMALS);
}

#[test]
fn test__update_token_metadata_on_mint_sets_when_absent() {
    let mut state = COMPONENT_STATE();

    state._update_token_metadata(ZERO, TOKEN_ID, NAME(), SYMBOL(), DECIMALS);

    assert_eq!(state.name(TOKEN_ID), NAME());
    assert_eq!(state.symbol(TOKEN_ID), SYMBOL());
    assert_eq!(state.decimals(TOKEN_ID), DECIMALS);
}

#[test]
fn test__update_token_metadata_on_mint_does_not_overwrite_if_exists() {
    let mut state = COMPONENT_STATE();

    state._set_token_metadata(TOKEN_ID, NAME(), SYMBOL(), DECIMALS);
    state._update_token_metadata(ZERO, TOKEN_ID, NAME_2(), SYMBOL_2(), DECIMALS_2);

    assert_eq!(state.name(TOKEN_ID), NAME());
    assert_eq!(state.symbol(TOKEN_ID), SYMBOL());
    assert_eq!(state.decimals(TOKEN_ID), DECIMALS);
}

#[test]
fn test__update_token_metadata_on_transfer_does_nothing_when_absent() {
    let mut state = COMPONENT_STATE();
    let sender: ContractAddress = OWNER;

    state._update_token_metadata(sender, TOKEN_ID, NAME(), SYMBOL(), DECIMALS);

    let empty: ByteArray = "";
    assert_eq!(state.name(TOKEN_ID), empty);
    assert_eq!(state.symbol(TOKEN_ID), empty);
    assert_eq!(state.decimals(TOKEN_ID), 0);
}

#[test]
fn test__update_token_metadata_on_transfer_does_not_overwrite_existing() {
    let mut state = COMPONENT_STATE();
    let sender: ContractAddress = OWNER;

    state._set_token_metadata(TOKEN_ID, NAME(), SYMBOL(), DECIMALS);
    state._update_token_metadata(sender, TOKEN_ID, NAME_2(), SYMBOL_2(), DECIMALS_2);

    assert_eq!(state.name(TOKEN_ID), NAME());
    assert_eq!(state.symbol(TOKEN_ID), SYMBOL());
    assert_eq!(state.decimals(TOKEN_ID), DECIMALS);
}
