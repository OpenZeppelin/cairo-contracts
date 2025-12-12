use openzeppelin_interfaces::erc6909::IERC6909_TOKEN_SUPPLY_ID;
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::mocks::erc6909::ERC6909TokenSupplyMock;
use openzeppelin_testing::constants::{OWNER, RECIPIENT, TOKEN_ID, VALUE, ZERO};
use starknet::ContractAddress;
use crate::erc6909::extensions::erc6909_token_supply::ERC6909TokenSupplyComponent;
use crate::erc6909::extensions::erc6909_token_supply::ERC6909TokenSupplyComponent::{
    ERC6909TokenSupplyImpl, InternalImpl,
};

type ComponentState =
    ERC6909TokenSupplyComponent::ComponentState<ERC6909TokenSupplyMock::ContractState>;

fn CONTRACT_STATE() -> ERC6909TokenSupplyMock::ContractState {
    ERC6909TokenSupplyMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC6909TokenSupplyComponent::component_state_for_testing()
}

#[test]
fn test_initializer_registers_interface() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer();

    assert!(mock_state.supports_interface(IERC6909_TOKEN_SUPPLY_ID));
    assert!(mock_state.supports_interface(ISRC5_ID));
}

#[test]
fn test_total_supply_default_zero() {
    let state = COMPONENT_STATE();
    assert_eq!(state.total_supply(TOKEN_ID), 0);
}

#[test]
fn test__update_token_supply_increments_on_mint() {
    let mut state = COMPONENT_STATE();
    let before = state.total_supply(TOKEN_ID);

    state._update_token_supply(ZERO, RECIPIENT, TOKEN_ID, VALUE);

    assert_eq!(state.total_supply(TOKEN_ID), before + VALUE);
}

#[test]
fn test__update_token_supply_decrements_on_burn() {
    let mut state = COMPONENT_STATE();

    state._update_token_supply(ZERO, RECIPIENT, TOKEN_ID, VALUE + 1);
    let mid = state.total_supply(TOKEN_ID);

    state._update_token_supply(OWNER, ZERO, TOKEN_ID, 1);

    assert_eq!(state.total_supply(TOKEN_ID), mid - 1);
}

#[test]
fn test__update_token_supply_no_change_on_transfer() {
    let mut state = COMPONENT_STATE();

    state._update_token_supply(ZERO, RECIPIENT, TOKEN_ID, VALUE);
    let before = state.total_supply(TOKEN_ID);

    let sender: ContractAddress = OWNER;
    let receiver: ContractAddress = RECIPIENT;
    state._update_token_supply(sender, receiver, TOKEN_ID, VALUE);

    assert_eq!(state.total_supply(TOKEN_ID), before);
}
