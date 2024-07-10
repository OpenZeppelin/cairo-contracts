use openzeppelin::tests::mocks::erc721_uri_storage_mocks::ERC721URIStorageMock;
use openzeppelin::tests::utils::constants::{
    ZERO, OWNER, RECIPIENT, NAME, SYMBOL, TOKEN_ID, TOKEN_ID_2, BASE_URI, BASE_URI_2, SAMPLE_URI
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721Component::InternalImpl as ERC721InternalImpl;
use openzeppelin::token::erc721::extensions::ERC721URIStorageComponent::{
    ERC721URIStorageImpl, InternalImpl
};
use openzeppelin::token::erc721::extensions::ERC721URIStorageComponent;
use openzeppelin::token::erc721::extensions::erc721_uri_storage::ERC721URIStorageComponent::MetadataUpdated;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;


//
// Setup
//

type ComponentState =
    ERC721URIStorageComponent::ComponentState<ERC721URIStorageMock::ContractState>;

fn CONTRACT_STATE() -> ERC721URIStorageMock::ContractState {
    ERC721URIStorageMock::contract_state_for_testing()
}
fn COMPONENT_STATE() -> ComponentState {
    ERC721URIStorageComponent::component_state_for_testing()
}

//constructor is inside only
fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();
    mock_state.erc721.initializer(NAME(), SYMBOL(), "");
    mock_state.erc721.mint(OWNER(), TOKEN_ID);
    utils::drop_event(ZERO());
    state
}

#[test]
fn test_token_uri_when_not_set() {
    let state = setup();
    let uri = state.token_uri(TOKEN_ID);
    let empty = 0;
    assert_eq!(uri.len(), empty);
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

    state.set_token_uri(TOKEN_ID, SAMPLE_URI());
    assert_only_event_metadata_update(ZERO(), TOKEN_ID);

    let expected = SAMPLE_URI();
    let uri = state.token_uri(TOKEN_ID);

    assert_eq!(uri, expected);
}

#[test]
fn test_set_token_uri_nonexistent() {
    let mut state = setup();

    state.set_token_uri(TOKEN_ID_2, SAMPLE_URI());
    assert_only_event_metadata_update(ZERO(), TOKEN_ID_2);

    let mut mock_contract_state = CONTRACT_STATE();
    //check accessible after minting
    mock_contract_state.erc721.mint(RECIPIENT(), TOKEN_ID_2);

    let expected = SAMPLE_URI();
    let uri = state.token_uri(TOKEN_ID_2);

    assert_eq!(uri, expected);
}

#[test]
fn test_token_uri_with_base_uri() {
    let mut state = setup();

    let mut mock_contract_state = CONTRACT_STATE();
    mock_contract_state.erc721._set_base_uri(BASE_URI());
    state.set_token_uri(TOKEN_ID, SAMPLE_URI());

    let token_uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI(), SAMPLE_URI());
    assert_eq!(token_uri, expected);
}

#[test]
fn test_base_uri_2_is_set_as_prefix() {
    let mut state = setup();

    let mut mock_contract_state = CONTRACT_STATE();
    mock_contract_state.erc721._set_base_uri(BASE_URI());
    state.set_token_uri(TOKEN_ID, SAMPLE_URI());

    mock_contract_state.erc721._set_base_uri(BASE_URI_2());

    let token_uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI_2(), SAMPLE_URI());
    assert_eq!(token_uri, expected);
}

#[test]
fn test_token_uri_with_base_uri_and_token_id() {
    let mut state = setup();

    let mut mock_contract_state = CONTRACT_STATE();
    mock_contract_state.erc721._set_base_uri(BASE_URI());

    let token_uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI(), TOKEN_ID);
    assert_eq!(token_uri, expected);
}

// todo: add this test
// todo: test and provide transaction hash
//#[test]
//fn test_token_uri_persists_when_burned_and_minted() {
//    let mut state = setup();
//
//    state.set_token_uri(TOKEN_ID, SAMPLE_URI());
//
//    let mut mock_contract_state = CONTRACT_STATE();
//    mock_contract_state.erc721.burn(TOKEN_ID);
//
//    //must panic with error 'ERC721: invalid token ID'
//    state.token_uri(TOKEN_ID);
//
//    mock_contract_state.erc721.mint(OWNER(), TOKEN_ID);
//
//    let token_uri = state.token_uri(TOKEN_ID);
//    let expected = SAMPLE_URI();
//    assert_eq!(token_uri, expected);
//}

//
// Helpers
//

pub fn assert_event_metadata_update(contract: ContractAddress, token_id: u256) {
    let event = utils::pop_log::<ERC721URIStorageComponent::Event>(contract).unwrap();
    let expected = ERC721URIStorageComponent::Event::MetadataUpdated(MetadataUpdated { token_id });
    assert!(event == expected);
}

fn assert_only_event_metadata_update(contract: ContractAddress, token_id: u256) {
    assert_event_metadata_update(contract, token_id);
    utils::assert_no_events_left(contract);
}
