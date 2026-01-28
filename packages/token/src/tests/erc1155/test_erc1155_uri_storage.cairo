use openzeppelin_test_common::erc1155::setup_account;
use openzeppelin_test_common::mocks::erc1155::ERC1155URIStorageMock;
use openzeppelin_testing::constants::{EMPTY_DATA, TOKEN_ID, TOKEN_ID_2, TOKEN_VALUE};
use openzeppelin_testing::events::{EventSpyExt, EventSpyQueue, ExpectedEvent};
use openzeppelin_testing::spy_events;
use snforge_std::test_address;
use starknet::ContractAddress;
use crate::erc1155::ERC1155Component::{
    ERC1155Impl, ERC1155MetadataURIImpl, InternalImpl as ERC1155InternalImpl,
};
use crate::erc1155::extensions::erc1155_uri_storage::ERC1155URIStorageComponent::InternalImpl as ERC1155URIStorageInternalImpl;

//
// Setup
//

fn CONTRACT_STATE() -> ERC1155URIStorageMock::ContractState {
    ERC1155URIStorageMock::contract_state_for_testing()
}

fn setup() -> ERC1155URIStorageMock::ContractState {
    let mut state = CONTRACT_STATE();
    state.erc1155.initializer("https://example.com/");
    state
}

fn setup_with_token() -> (ERC1155URIStorageMock::ContractState, ContractAddress) {
    let mut state = setup();
    let owner = setup_account();
    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    (state, owner)
}

fn setup_with_empty_base_uri() -> ERC1155URIStorageMock::ContractState {
    let mut state = CONTRACT_STATE();
    state.erc1155.initializer("");
    state
}

//
// uri
//

#[test]
fn test_uri_with_base_uri_and_no_token_uri() {
    let (state, _) = setup_with_token();

    // When no token URI is set, should fall back to base ERC1155 URI
    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "https://example.com/");
}

#[test]
fn test_uri_with_base_uri_and_token_uri() {
    let (mut state, _) = setup_with_token();
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "token/123.json");

    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "token/123.json");
}

#[test]
fn test_uri_with_storage_base_uri_and_token_uri() {
    let (mut state, _) = setup_with_token();
    state.erc1155_uri_storage.set_base_uri("https://cdn.example.com/");
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "metadata/123.json");

    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "https://cdn.example.com/metadata/123.json");
}

#[test]
fn test_uri_with_no_base_uri_and_token_uri() {
    let mut state = setup_with_empty_base_uri();
    let owner = setup_account();
    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "ipfs://CustomTokenURI");

    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "ipfs://CustomTokenURI");
}

#[test]
fn test_uri_with_no_base_uri_and_no_token_uri() {
    let mut state = setup_with_empty_base_uri();
    let owner = setup_account();
    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());

    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "");
}

//
// set_token_uri
//

#[test]
fn test_set_token_uri_emits_event() {
    let mut spy = spy_events();
    let (mut state, _) = setup_with_token();
    let contract_address = test_address();

    // Drop mint event
    spy.drop_all_events();

    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "custom_uri");

    spy.assert_only_event_uri(contract_address, "custom_uri", TOKEN_ID);
}

#[test]
fn test_set_token_uri_emits_event_with_base_uri() {
    let mut spy = spy_events();
    let (mut state, _) = setup_with_token();
    let contract_address = test_address();

    state.erc1155_uri_storage.set_base_uri("https://base.com/");
    spy.drop_all_events();

    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "token.json");

    spy.assert_only_event_uri(contract_address, "https://base.com/token.json", TOKEN_ID);
}

#[test]
fn test_set_token_uri_multiple_times() {
    let (mut state, _) = setup_with_token();

    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "first_uri");
    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "first_uri");

    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "second_uri");
    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "second_uri");
}

#[test]
fn test_set_token_uri_for_nonexistent_token() {
    let mut state = setup();

    // ERC1155 allows setting URI for any token ID
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID_2, "some_uri");
    let uri = state.erc1155.uri(TOKEN_ID_2);
    assert_eq!(uri, "some_uri");
}

//
// set_base_uri
//

#[test]
fn test_set_base_uri() {
    let mut state = setup();

    state.erc1155_uri_storage.set_base_uri("https://newbase.com/");
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "token.json");

    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "https://newbase.com/token.json");
}

#[test]
fn test_set_base_uri_changes_existing_token_uris() {
    let (mut state, _) = setup_with_token();

    state.erc1155_uri_storage.set_base_uri("https://first.com/");
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "token.json");

    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "https://first.com/token.json");

    // Change base URI
    state.erc1155_uri_storage.set_base_uri("https://second.com/");
    let uri = state.erc1155.uri(TOKEN_ID);
    assert_eq!(uri, "https://second.com/token.json");
}

//
// Integration tests
//

#[test]
fn test_multiple_tokens_with_different_uris() {
    let mut state = setup();
    let owner = setup_account();

    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID_2, TOKEN_VALUE, EMPTY_DATA());

    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "token_1_uri");
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID_2, "token_2_uri");

    assert_eq!(state.erc1155.uri(TOKEN_ID), "token_1_uri");
    assert_eq!(state.erc1155.uri(TOKEN_ID_2), "token_2_uri");
}

#[test]
fn test_multiple_tokens_with_shared_base_uri() {
    let mut state = setup();
    let owner = setup_account();

    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID_2, TOKEN_VALUE, EMPTY_DATA());

    state.erc1155_uri_storage.set_base_uri("https://api.example.com/tokens/");
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "1.json");
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID_2, "2.json");

    assert_eq!(state.erc1155.uri(TOKEN_ID), "https://api.example.com/tokens/1.json");
    assert_eq!(state.erc1155.uri(TOKEN_ID_2), "https://api.example.com/tokens/2.json");
}

#[test]
fn test_token_without_uri_falls_back_to_erc1155_uri() {
    let mut state = setup();
    let owner = setup_account();

    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID_2, TOKEN_VALUE, EMPTY_DATA());

    // Only set URI for TOKEN_ID
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "custom_uri");

    // TOKEN_ID has custom URI
    assert_eq!(state.erc1155.uri(TOKEN_ID), "custom_uri");

    // TOKEN_ID_2 falls back to ERC1155 base URI
    assert_eq!(state.erc1155.uri(TOKEN_ID_2), "https://example.com/");
}

#[test]
fn test_multiple_events_emitted() {
    let mut spy = spy_events();
    let (mut state, _) = setup_with_token();
    let contract_address = test_address();

    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "uri_1");
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "uri_2");

    spy.assert_event_uri(contract_address, "uri_1", TOKEN_ID);
    spy.assert_event_uri(contract_address, "uri_2", TOKEN_ID);
}

#[test]
fn test_clear_token_uri() {
    let (mut state, _) = setup_with_token();

    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "custom_uri");
    assert_eq!(state.erc1155.uri(TOKEN_ID), "custom_uri");

    // Clear token URI by setting empty string
    state.erc1155_uri_storage.set_token_uri(TOKEN_ID, "");

    // Should fall back to ERC1155 base URI
    assert_eq!(state.erc1155.uri(TOKEN_ID), "https://example.com/");
}

//
// Event helpers
//

#[generate_trait]
impl ERC1155URIStorageSpyHelpersImpl of ERC1155URIStorageSpyHelpers {
    fn assert_event_uri(
        ref self: EventSpyQueue, contract: ContractAddress, value: ByteArray, id: u256,
    ) {
        let expected = ExpectedEvent::new().key(selector!("URI")).key(id).data(value);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_uri(
        ref self: EventSpyQueue, contract: ContractAddress, value: ByteArray, id: u256,
    ) {
        self.assert_event_uri(contract, value, id);
        self.assert_no_events_left_from(contract);
    }
}
