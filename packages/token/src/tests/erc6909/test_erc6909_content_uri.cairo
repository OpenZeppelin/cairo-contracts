use openzeppelin_interfaces::erc6909::IERC6909_CONTENT_URI_ID;
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::mocks::erc6909::ERC6909ContentURIMock;
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent, spy_events};
use snforge_std::test_address;
use crate::erc6909::extensions::erc6909_content_uri::ERC6909ContentURIComponent;
use crate::erc6909::extensions::erc6909_content_uri::ERC6909ContentURIComponent::{
    ERC6909ContentURIImpl, InternalImpl,
};


fn CONTRACT_URI() -> ByteArray {
    "ipfs://contract/"
}

fn TOKEN_URI() -> ByteArray {
    "ipfs://token/1234"
}

const SAMPLE_ID: u256 = 1234;


type ComponentState =
    ERC6909ContentURIComponent::ComponentState<ERC6909ContentURIMock::ContractState>;

fn CONTRACT_STATE() -> ERC6909ContentURIMock::ContractState {
    ERC6909ContentURIMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC6909ContentURIComponent::component_state_for_testing()
}


#[test]
fn test_initializer_registers_interface() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer();

    let supports_content_uri = mock_state.supports_interface(IERC6909_CONTENT_URI_ID);
    assert!(supports_content_uri);

    let supports_isrc5 = mock_state.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);
}


#[test]
fn test_contract_uri_default_is_empty() {
    let state = COMPONENT_STATE();
    let empty: ByteArray = "";
    assert_eq!(state.contract_uri(), empty);
}

#[test]
fn test_set_contract_uri() {
    let mut state = COMPONENT_STATE();
    let contract_address = test_address();

    state.initializer();

    let mut spy = spy_events();
    state._set_contract_uri(CONTRACT_URI());

    spy.assert_only_event_contract_uri_updated(contract_address);
    assert_eq!(state.contract_uri(), CONTRACT_URI());
}

#[test]
fn test_set_contract_uri_empty() {
    let mut state = COMPONENT_STATE();

    state.initializer();
    state._set_contract_uri("");

    let empty: ByteArray = "";
    assert_eq!(state.contract_uri(), empty);
}


#[test]
fn test_token_uri_default_is_empty() {
    let state = COMPONENT_STATE();
    let empty: ByteArray = "";
    assert_eq!(state.token_uri(SAMPLE_ID), empty);
}

#[test]
fn test_set_token_uri() {
    let mut state = COMPONENT_STATE();
    let contract_address = test_address();

    state.initializer();

    let mut spy = spy_events();
    state._set_token_uri(SAMPLE_ID, TOKEN_URI());

    spy.assert_only_event_uri(contract_address, TOKEN_URI(), SAMPLE_ID);
    assert_eq!(state.token_uri(SAMPLE_ID), TOKEN_URI());
}

#[test]
fn test_token_uri_independent_of_contract_uri() {
    let mut state = COMPONENT_STATE();

    state.initializer();
    state._set_contract_uri(CONTRACT_URI());
    state._set_token_uri(SAMPLE_ID, TOKEN_URI());

    // Token URI is independent of contract URI
    assert_eq!(state.contract_uri(), CONTRACT_URI());
    assert_eq!(state.token_uri(SAMPLE_ID), TOKEN_URI());
}

#[test]
fn test_different_token_ids_have_different_uris() {
    let mut state = COMPONENT_STATE();

    state.initializer();

    let uri_1: ByteArray = "ipfs://token/1";
    let uri_2: ByteArray = "ipfs://token/2";

    state._set_token_uri(1, uri_1.clone());
    state._set_token_uri(2, uri_2.clone());

    assert_eq!(state.token_uri(1), uri_1);
    assert_eq!(state.token_uri(2), uri_2);
}


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
