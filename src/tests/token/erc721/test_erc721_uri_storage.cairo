use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::introspection::src5;
use openzeppelin::introspection;
use openzeppelin::tests::mocks::erc721_uri_storage_mocks::ERC721URIstorageMock;
use openzeppelin::tests::utils::constants::{
    DATA, ZERO, OWNER, RECIPIENT, NAME, SYMBOL, TOKEN_ID, TOKEN_ID_2, PUBKEY, BASE_URI, BASE_URI_2,
    SAMPLE_URI
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721Component::ERC721Impl;
use openzeppelin::token::erc721::ERC721Component::InternalImpl as ERC721InternalImpl;
use openzeppelin::token::erc721::ERC721Component;
use openzeppelin::token::erc721::extensions::ERC721URIstorageComponent::{
    ERC721URIstorageImpl, InternalImpl
};
use openzeppelin::token::erc721::extensions::ERC721URIstorageComponent;
use openzeppelin::token::erc721::extensions::erc721_uri_storage::ERC721URIstorageComponent::MetadataUpdate;

use openzeppelin::token::erc721::interface::IERC721;
use openzeppelin::token::erc721;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::storage::{StorageMapMemberAccessTrait, StorageMemberAccessTrait};
use starknet::testing;


//
// Setup
//

type ComponentState =
    ERC721URIstorageComponent::ComponentState<ERC721URIstorageMock::ContractState>;

fn CONTRACT_STATE() -> ERC721URIstorageMock::ContractState {
    ERC721URIstorageMock::contract_state_for_testing()
}
fn COMPONENT_STATE() -> ComponentState {
    ERC721URIstorageComponent::component_state_for_testing()
}

//constructor is inside only
fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();
    mock_state.erc721.initializer(NAME(), SYMBOL(), BASE_URI());
    mock_state.erc721.mint(OWNER(), TOKEN_ID);
    utils::drop_event(ZERO());
    state
}

#[test]
fn test_token_uri() {
    let state = setup();
    let uri = state.token_uri(TOKEN_ID);
    let expected = "";
    assert_eq!(uri, expected);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_token_uri_non_minted() {
    let state = setup();
    state.token_uri(TOKEN_ID_2);
}

#[test]
fn test_set_token_uri() {
    let mut state = setup();

    state.set_token_uri(TOKEN_ID, SAMPLE_URI()); //internal function?
    assert_only_event_metadata_update(ZERO(), TOKEN_ID); //checking event is emitted or not 

    let expected = format!("{}", SAMPLE_URI());
    let uri = state.token_uri(TOKEN_ID);

    assert_eq!(uri, expected);
}

#[test]
fn test_set_token_uri_nonexistent() {
    let mut state = setup();

    state.set_token_uri(TOKEN_ID_2, SAMPLE_URI());
    assert_only_event_metadata_update(ZERO(), TOKEN_ID_2); //checking event is emitted or not 

    let mut mock_contract_state = CONTRACT_STATE();
    //check accessible after minting
    mock_contract_state.erc721.mint(RECIPIENT(), TOKEN_ID_2);

    let expected = format!("{}", SAMPLE_URI());
    let uri = state.token_uri(TOKEN_ID);

    assert_eq!(uri, expected);
}

#[test]
fn test_set_base_uri() {
    let mut _state = setup(); //its the component state

    let mut mock_contract_state = CONTRACT_STATE();
    mock_contract_state.erc721._set_base_uri(BASE_URI());

    let base_uri = mock_contract_state.erc721._base_uri(); //internal of ERC721   

    assert_eq!(base_uri, BASE_URI());
}

#[test]
fn test_base_uri_is_prefix() {
    let mut state = setup(); //its the component state

    let mut mock_contract_state = CONTRACT_STATE();
    mock_contract_state.erc721._set_base_uri(BASE_URI());
    state.set_token_uri(TOKEN_ID, SAMPLE_URI());

    let token_uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI(), SAMPLE_URI());
    assert_eq!(token_uri, expected);
}

#[test]
fn test_base_uri_2_is_set_as_prefix() {
    let mut state = setup(); //its the component state

    let mut mock_contract_state = CONTRACT_STATE();
    mock_contract_state.erc721._set_base_uri(BASE_URI_2());

    state.set_token_uri(TOKEN_ID, SAMPLE_URI());

    let token_uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI_2(), SAMPLE_URI());
    assert_eq!(token_uri, expected);
}

#[test]
fn test_base_uri_and_token_id() {
    let mut state = setup(); //its the component state

    let mut mock_contract_state = CONTRACT_STATE();
    mock_contract_state.erc721._set_base_uri(BASE_URI());

    let token_uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI(), TOKEN_ID);
    assert_eq!(token_uri, expected);
}

//
// Helpers
//
pub fn assert_event_metadata_update(contract: ContractAddress, token_id: u256) {
    let event = utils::pop_log::<ERC721URIstorageComponent::Event>(contract).unwrap();
    let expected = ERC721URIstorageComponent::Event::MetadataUpdate(MetadataUpdate { token_id });
    assert!(event == expected);

    //check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("MetadataUpdate"));
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span())
}

pub fn assert_only_event_metadata_update(contract: ContractAddress, token_id: u256) {
    assert_event_metadata_update(contract, token_id);
    utils::assert_no_events_left(contract);
}
