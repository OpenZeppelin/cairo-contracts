use openzeppelin_access::ownable::OwnableComponent;
use openzeppelin_access::ownable::OwnableComponent::InternalImpl as OwnableInternalImpl;
use openzeppelin_test_common::mocks::erc6909::ERC6909ContentURIOwnableMock;
use openzeppelin_testing::constants::{OTHER, OWNER};
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent, spy_events};
use snforge_std::{start_cheat_caller_address, test_address};
use crate::erc6909::extensions::erc6909_content_uri::ERC6909ContentURIComponent;
use crate::erc6909::extensions::erc6909_content_uri::ERC6909ContentURIComponent::{
    ERC6909ContentURIAdminOwnableImpl, ERC6909ContentURIImpl, InternalImpl,
};

type MockState = ERC6909ContentURIOwnableMock::ContractState;
type ComponentState = ERC6909ContentURIComponent::ComponentState<MockState>;
type OwnableComponentState = OwnableComponent::ComponentState<MockState>;

fn CONTRACT_URI() -> ByteArray {
    "ipfs://contract/"
}

fn TOKEN_URI() -> ByteArray {
    "ipfs://token/1234"
}

const SAMPLE_ID: u256 = 1234;

fn COMPONENT_STATE() -> ComponentState {
    ERC6909ContentURIComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer();

    let mut ownable_state: OwnableComponentState = OwnableComponent::component_state_for_testing();
    ownable_state.initializer(OWNER);

    state
}

//
// IERC6909ContentUriAdmin - Ownable
//

#[test]
fn test_set_contract_uri() {
    let mut state = setup();
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(test_address(), OWNER);
    state.set_contract_uri(CONTRACT_URI());

    spy.assert_only_event_contract_uri_updated(contract_address);
    assert_eq!(state.contract_uri(), CONTRACT_URI());
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_contract_uri_unauthorized() {
    let mut state = setup();

    start_cheat_caller_address(test_address(), OTHER);
    state.set_contract_uri(CONTRACT_URI());
}

#[test]
fn test_set_token_uri() {
    let mut state = setup();
    let contract_address = test_address();

    let mut spy = spy_events();
    start_cheat_caller_address(test_address(), OWNER);
    state.set_token_uri(SAMPLE_ID, TOKEN_URI());

    spy.assert_only_event_uri(contract_address, TOKEN_URI(), SAMPLE_ID);
    assert_eq!(state.token_uri(SAMPLE_ID), TOKEN_URI());
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_token_uri_unauthorized() {
    let mut state = setup();

    start_cheat_caller_address(test_address(), OTHER);
    state.set_token_uri(SAMPLE_ID, TOKEN_URI());
}

//
// Helpers
//

#[generate_trait]
impl ERC6909ContentURISpyHelpersImpl of ERC6909ContentURISpyHelpers {
    fn assert_only_event_contract_uri_updated(
        ref self: EventSpy, contract: starknet::ContractAddress,
    ) {
        let expected = ExpectedEvent::new().key(selector!("ContractURIUpdated"));
        self.assert_emitted_single(contract, expected);
        self.assert_no_events_left_from(contract);
    }

    fn assert_only_event_uri(
        ref self: EventSpy, contract: starknet::ContractAddress, value: ByteArray, id: u256,
    ) {
        let expected = ExpectedEvent::new().key(selector!("URI")).key(id).data(value);
        self.assert_emitted_single(contract, expected);
        self.assert_no_events_left_from(contract);
    }
}
