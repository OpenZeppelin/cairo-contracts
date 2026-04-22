use openzeppelin_access::ownable::OwnableComponent;
use openzeppelin_access::ownable::OwnableComponent::InternalImpl as OwnableInternalImpl;
use openzeppelin_test_common::erc6909::ERC6909MetadataSpyHelpers;
use openzeppelin_test_common::mocks::erc6909::ERC6909MetadataOwnableMock;
use openzeppelin_testing::constants::{DECIMALS, NAME, OTHER, OWNER, SYMBOL, TOKEN_ID};
use openzeppelin_testing::spy_events;
use snforge_std::{start_cheat_caller_address, test_address};
use crate::erc6909::extensions::erc6909_metadata::ERC6909MetadataComponent;
use crate::erc6909::extensions::erc6909_metadata::ERC6909MetadataComponent::{
    ERC6909MetadataAdminOwnableImpl, ERC6909MetadataImpl, InternalImpl,
};

type MockState = ERC6909MetadataOwnableMock::ContractState;
type ComponentState = ERC6909MetadataComponent::ComponentState<MockState>;
type OwnableComponentState = OwnableComponent::ComponentState<MockState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC6909MetadataComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer();

    let mut ownable_state: OwnableComponentState = OwnableComponent::component_state_for_testing();
    ownable_state.initializer(OWNER);

    state
}

//
// IERC6909MetadataAdmin - Ownable
//

#[test]
fn test_set_token_name() {
    let mut state = setup();
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(test_address(), OWNER);
    state.set_token_name(TOKEN_ID, NAME());

    spy.assert_only_event_name_updated(contract_address, TOKEN_ID, NAME());
    assert_eq!(state.name(TOKEN_ID), NAME());
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_token_name_unauthorized() {
    let mut state = setup();

    start_cheat_caller_address(test_address(), OTHER);
    state.set_token_name(TOKEN_ID, NAME());
}

#[test]
fn test_set_token_symbol() {
    let mut state = setup();
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(test_address(), OWNER);
    state.set_token_symbol(TOKEN_ID, SYMBOL());

    spy.assert_only_event_symbol_updated(contract_address, TOKEN_ID, SYMBOL());
    assert_eq!(state.symbol(TOKEN_ID), SYMBOL());
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_token_symbol_unauthorized() {
    let mut state = setup();

    start_cheat_caller_address(test_address(), OTHER);
    state.set_token_symbol(TOKEN_ID, SYMBOL());
}

#[test]
fn test_set_token_decimals() {
    let mut state = setup();
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(test_address(), OWNER);
    state.set_token_decimals(TOKEN_ID, DECIMALS);

    spy.assert_only_event_decimals_updated(contract_address, TOKEN_ID, DECIMALS);
    assert_eq!(state.decimals(TOKEN_ID), DECIMALS);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_token_decimals_unauthorized() {
    let mut state = setup();

    start_cheat_caller_address(test_address(), OTHER);
    state.set_token_decimals(TOKEN_ID, DECIMALS);
}
