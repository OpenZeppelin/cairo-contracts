use openzeppelin_interfaces::erc6909::IERC6909_CONTENT_URI_ID;
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::mocks::erc6909::ERC6909ContentURIMock;
use crate::erc6909::extensions::erc6909_content_uri::ERC6909ContentURIComponent;
use crate::erc6909::extensions::erc6909_content_uri::ERC6909ContentURIComponent::{
    ERC6909ContentURIImpl, InternalImpl,
};


fn CONTRACT_URI() -> ByteArray {
    "ipfs://erc6909/"
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
fn test_initializer_registers_interface_and_sets_uri() {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();

    let uri = CONTRACT_URI();
    state.initializer(uri);

    let supports_content_uri = mock_state.supports_interface(IERC6909_CONTENT_URI_ID);
    assert!(supports_content_uri);

    let supports_isrc5 = mock_state.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);

    assert_eq!(state.contract_uri(), uri);
}


#[test]
fn test_contract_uri_default_is_empty() {
    let state = COMPONENT_STATE();
    let empty: ByteArray = "";
    assert_eq!(state.contract_uri(), empty);
}

#[test]
fn test_contract_uri_after_initializer_returns_set_value() {
    let mut state = COMPONENT_STATE();
    let uri = CONTRACT_URI();
    state.initializer(uri);

    assert_eq!(state.contract_uri(), uri);
}


#[test]
fn test_token_uri_concatenates_contract_uri_and_id() {
    let mut state = COMPONENT_STATE();
    let uri = CONTRACT_URI();
    state.initializer(uri);

    let expected = format!("{}{}", uri, SAMPLE_ID);
    assert_eq!(state.token_uri(SAMPLE_ID), expected);
}

#[test]
fn test_token_uri_when_contract_uri_not_set_is_empty() {
    let state = COMPONENT_STATE();
    let empty: ByteArray = "";
    assert_eq!(state.token_uri(SAMPLE_ID), empty);
}
