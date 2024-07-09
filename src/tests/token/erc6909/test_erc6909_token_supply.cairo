use core::integer::BoundedInt;
use core::num::traits::Zero;
use openzeppelin::tests::mocks::erc6909_token_supply_mocks::DualCaseERC6909TokenSupplyMock;
use openzeppelin::tests::utils::constants::{OWNER, SPENDER, RECIPIENT, SUPPLY, ZERO};
use openzeppelin::tests::utils;
use openzeppelin::token::erc6909::ERC6909Component::{
    InternalImpl as InternalERC6909Impl, ERC6909Impl
};
use openzeppelin::token::erc6909::extensions::ERC6909TokenSupplyComponent::{
    ERC6909TokenSupplyImpl, InternalImpl,
};
use openzeppelin::token::erc6909::extensions::ERC6909TokenSupplyComponent;
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
    ERC6909TokenSupplyComponent::ComponentState<DualCaseERC6909TokenSupplyMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseERC6909TokenSupplyMock::ContractState {
    DualCaseERC6909TokenSupplyMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC6909TokenSupplyComponent::component_state_for_testing()
}

fn setup() -> (ComponentState, DualCaseERC6909TokenSupplyMock::ContractState) {
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
fn test__state_total_supply() {
    let (mut state, _) = setup();
    let mut id_supply = state.ERC6909TokenSupply_total_supply.read(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);
}

#[test]
fn test__state_no_total_supply() {
    let (mut state, _) = setup();
    let mut id_supply = state.ERC6909TokenSupply_total_supply.read(TOKEN_ID + 69);
    assert_eq!(id_supply, 0);
}


#[test]
fn test_total_supply() {
    let (mut state, _) = setup();
    let mut id_supply = state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);
}

#[test]
fn test_no_total_supply() {
    let (mut state, _) = setup();
    let mut id_supply = state.total_supply(TOKEN_ID + 69);
    assert_eq!(id_supply, 0);
}

#[test]
fn test_total_supply_contract() {
    let (_, mut mock_state) = setup();
    let mut id_supply = mock_state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);
}
//
// mint & burn
//

#[test]
fn test_mint_increase_supply() {
    let (_, mut mock_state) = setup();
    let mut id_supply = mock_state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);

    let new_token_id = TOKEN_ID + 69;

    testing::set_caller_address(OWNER());
    mock_state.erc6909.mint(OWNER(), new_token_id, SUPPLY * 2);

    let mut old_token_id_supply = mock_state.total_supply(TOKEN_ID);
    let mut new_token_id_supply = mock_state.total_supply(new_token_id);
    assert_eq!(old_token_id_supply, SUPPLY);
    assert_eq!(new_token_id_supply, SUPPLY * 2);
}

#[test]
fn test_burn_decrease_supply() {
    let (_, mut mock_state) = setup();
    let mut id_supply = mock_state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);

    let new_token_id = TOKEN_ID + 69;

    testing::set_caller_address(OWNER());
    mock_state.erc6909.mint(OWNER(), new_token_id, SUPPLY * 2);

    let mut new_token_id_supply = mock_state.total_supply(new_token_id);
    assert_eq!(new_token_id_supply, SUPPLY * 2);

    testing::set_caller_address(OWNER());
    mock_state.erc6909.burn(OWNER(), new_token_id, SUPPLY * 2);

    let mut new_token_id_supply = mock_state.total_supply(new_token_id);
    assert_eq!(new_token_id_supply, 0);
}

// transfer & transferFrom
#[test]
fn test_transfers_dont_change_supply() {
    let (_, mut mock_state) = setup();
    let mut id_supply = mock_state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);

    testing::set_caller_address(OWNER());
    mock_state.transfer(RECIPIENT(), TOKEN_ID, SUPPLY);

    let mut id_supply = mock_state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);

    testing::set_caller_address(RECIPIENT());
    mock_state.transfer(OWNER(), TOKEN_ID, SUPPLY / 2);

    let mut id_supply = mock_state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);
}

// transfer & transferFrom
#[test]
fn test_transfer_from_doesnt_change_supply() {
    let (_, mut mock_state) = setup();
    let mut id_supply = mock_state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);

    testing::set_caller_address(OWNER());
    mock_state.approve(SPENDER(), TOKEN_ID, SUPPLY);
    testing::set_caller_address(SPENDER());
    mock_state.transfer_from(OWNER(), SPENDER(), TOKEN_ID, SUPPLY);

    let mut id_supply = mock_state.total_supply(TOKEN_ID);
    assert_eq!(id_supply, SUPPLY);
}
