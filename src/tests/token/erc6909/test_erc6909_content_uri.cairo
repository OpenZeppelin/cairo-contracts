use core::integer::BoundedInt;
use core::num::traits::Zero;
use openzeppelin::tests::mocks::erc6909_content_uri_mocks::DualCaseERC6909ContentURIMock;
use openzeppelin::tests::utils::constants::{
    OWNER, SPENDER, RECIPIENT, SUPPLY, ZERO, BASE_URI, BASE_URI_2
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc6909::ERC6909Component::InternalImpl as InternalERC6909Impl;
use openzeppelin::token::erc6909::extensions::ERC6909ContentURIComponent::{
    ERC6909ContentURIImpl, InternalImpl,
};
use openzeppelin::token::erc6909::extensions::ERC6909ContentURIComponent;
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
    ERC6909ContentURIComponent::ComponentState<DualCaseERC6909ContentURIMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseERC6909ContentURIMock::ContractState {
    DualCaseERC6909ContentURIMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC6909ContentURIComponent::component_state_for_testing()
}

fn setup() -> (ComponentState, DualCaseERC6909ContentURIMock::ContractState) {
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
fn test_unset_content_uri() {
    let (mut state, _) = setup();
    let mut uri = state.contract_uri();
    assert_eq!(uri, "");
}

#[test]
fn test_unset_token_uri() {
    let (mut state, _) = setup();
    let uri = state.token_uri(TOKEN_ID);
    assert_eq!(uri, "");
}

//
// internal setters
//

#[test]
fn test_set_contract_uri() {
    let (mut state, _) = setup();
    testing::set_caller_address(OWNER());
    state.initializer(BASE_URI());
    let uri = state.contract_uri();
    assert_eq!(uri, BASE_URI());
}

#[test]
fn test_set_token_uri() {
    let (mut state, _) = setup();
    testing::set_caller_address(OWNER());
    state.initializer(BASE_URI());
    let uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI(), TOKEN_ID);
    assert_eq!(uri, expected);
}

// Updates the URI once set
#[test]
fn test_update_token_uri() {
    let (mut state, _) = setup();
    testing::set_caller_address(OWNER());
    state.initializer(BASE_URI());
    let mut uri = state.token_uri(TOKEN_ID);
    let mut expected = format!("{}{}", BASE_URI(), TOKEN_ID);
    assert_eq!(uri, expected);

    testing::set_caller_address(OWNER());
    state.initializer(BASE_URI_2());
    let mut uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI_2(), TOKEN_ID);
    assert_eq!(uri, expected);
}
