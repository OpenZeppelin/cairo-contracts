use core::integer::BoundedInt;
use core::num::traits::Zero;
use openzeppelin::tests::mocks::erc6909_metadata_mocks::DualCaseERC6909MetadataMock;
use openzeppelin::tests::utils::constants::{OWNER, SPENDER, RECIPIENT, SUPPLY, ZERO};
use openzeppelin::tests::utils;
use openzeppelin::token::erc6909::ERC6909Component::InternalImpl as InternalERC6909Impl;
use openzeppelin::token::erc6909::extensions::ERC6909MetadataComponent::{
    ERC6909MetadataImpl, InternalImpl,
};
use openzeppelin::token::erc6909::extensions::ERC6909MetadataComponent;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::storage::{StorageMapMemberAccessTrait, StorageMemberAccessTrait};
use starknet::testing;

use super::common::{
    assert_event_approval, assert_only_event_approval, assert_only_event_transfer,
    assert_only_event_operator_set, assert_event_operator_set
};

//
// Setup
//

const TOKEN_ID: u256 = 420;

type ComponentState =
    ERC6909MetadataComponent::ComponentState<DualCaseERC6909MetadataMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseERC6909MetadataMock::ContractState {
    DualCaseERC6909MetadataMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC6909MetadataComponent::component_state_for_testing()
}

fn setup() -> (ComponentState, DualCaseERC6909MetadataMock::ContractState) {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();
    mock_state.erc6909.mint(OWNER(), TOKEN_ID, SUPPLY);
    utils::drop_event(ZERO());
    (state, mock_state)
}

//
// Getters
//

#[test]
fn test_name() {
    let (mut state, _) = setup();
    let mut name = state.ERC6909Metadata_name.read(TOKEN_ID);
    assert_eq!(name, "");
}

#[test]
fn test_symbol() {
    let (mut state, _) = setup();
    let mut symbol = state.ERC6909Metadata_symbol.read(TOKEN_ID);
    assert_eq!(symbol, "");
}

#[test]
fn test_decimals() {
    let (mut state, _) = setup();
    let mut decimals = state.ERC6909Metadata_decimals.read(TOKEN_ID);
    assert_eq!(decimals, 0);
}

//
// internal setters
//

#[test]
fn test_set_name() {
    let (_, mut mock_state) = setup();
    testing::set_caller_address(OWNER());
    mock_state.erc6909_metadata._set_token_name(TOKEN_ID, "some token");
    let mut name = mock_state.name(TOKEN_ID);
    assert_eq!(name, "some token");

    let mut name = mock_state.name(TOKEN_ID + 69);
    assert_eq!(name, "");
}

#[test]
fn test_set_symbol() {
    let (_, mut mock_state) = setup();
    testing::set_caller_address(OWNER());
    mock_state.erc6909_metadata._set_token_symbol(TOKEN_ID, "some symbol");
    let mut symbol = mock_state.symbol(TOKEN_ID);
    assert_eq!(symbol, "some symbol");

    let mut symbol = mock_state.symbol(TOKEN_ID + 69);
    assert_eq!(symbol, "");
}

#[test]
fn test_set_decimals() {
    let (_, mut mock_state) = setup();
    testing::set_caller_address(OWNER());
    mock_state.erc6909_metadata._set_token_decimals(TOKEN_ID, 18);
    let mut decimals = mock_state.decimals(TOKEN_ID);
    assert_eq!(decimals, 18);

    let mut decimals = mock_state.decimals(TOKEN_ID + 69);
    assert_eq!(decimals, 0);
}
