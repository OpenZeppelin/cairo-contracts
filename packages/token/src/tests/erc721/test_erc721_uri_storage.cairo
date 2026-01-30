use openzeppelin_interfaces::erc721::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait,
};
use openzeppelin_test_common::mocks::erc721::{
    ERC721URIStorageMockABIDispatcher, ERC721URIStorageMockABIDispatcherTrait,
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{NAME, OWNER, SYMBOL};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_testing::spy_events;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;
use crate::erc721::extensions::erc721_uri_storage::ERC721URIStorageComponent;
use crate::erc721::extensions::erc721_uri_storage::ERC721URIStorageComponent::MetadataUpdate;

//
// Setup
//

#[derive(Copy, Drop)]
struct Dispatcher {
    contract_address: ContractAddress,
    erc721: IERC721Dispatcher,
    metadata: IERC721MetadataDispatcher,
    external: ERC721URIStorageMockABIDispatcher,
}

fn deploy(base_uri: ByteArray) -> Dispatcher {
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(base_uri);
    calldata.append_serde(OWNER);
    calldata.append_serde(TOKEN_ID);

    let contract_address = utils::declare_and_deploy("ERC721URIStorageMock", calldata);
    let erc721 = IERC721Dispatcher { contract_address };
    let external = ERC721URIStorageMockABIDispatcher { contract_address };
    let metadata = IERC721MetadataDispatcher { contract_address };
    Dispatcher { contract_address, erc721, metadata, external }
}

fn deploy_default() -> Dispatcher {
    let base_uri = "https://abc.com/";
    deploy(base_uri)
}

fn deploy_with_empty_base_uri() -> Dispatcher {
    let empty_uri = "";
    deploy(empty_uri)
}

const TOKEN_ID: u256 = 123;
const TOKEN_ID_2: u256 = 777;

//
// token_uri
//

#[test]
fn test_token_uri_with_base_uri_and_no_token_uri() {
    let dispatcher = deploy_default();
    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/123");
}

#[test]
fn test_token_uri_with_base_uri_and_token_uri() {
    let dispatcher = deploy_default();
    dispatcher.external.set_token_uri(TOKEN_ID, "custom_token_uri");

    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/custom_token_uri");
}

#[test]
fn test_token_uri_with_no_base_uri_and_token_uri() {
    let dispatcher = deploy_with_empty_base_uri();
    dispatcher.external.set_token_uri(TOKEN_ID, "ipfs://CustomTokenURI");

    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "ipfs://CustomTokenURI");
}

#[test]
fn test_token_uri_with_no_base_uri_and_no_token_uri() {
    let dispatcher = deploy_with_empty_base_uri();
    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "");
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_token_uri_nonexistent_token() {
    let dispatcher = deploy_default();
    dispatcher.metadata.token_uri(TOKEN_ID_2);
}

//
// set_token_uri
//

#[test]
fn test_set_token_uri_emits_event() {
    let mut spy = spy_events();
    let dispatcher = deploy_default();

    let custom_uri = "custom_uri";
    dispatcher.external.set_token_uri(TOKEN_ID, custom_uri);

    let expected_event = ERC721URIStorageComponent::Event::MetadataUpdate(
        MetadataUpdate { token_id: TOKEN_ID },
    );
    spy.assert_emitted_single(dispatcher.contract_address, expected_event);
}

#[test]
fn test_set_token_uri_multiple_times() {
    let dispatcher = deploy_default();

    dispatcher.external.set_token_uri(TOKEN_ID, "first_uri");

    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/first_uri");

    dispatcher.external.set_token_uri(TOKEN_ID, "second_uri");
    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/second_uri");
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_set_token_uri_nonexistent_token() {
    let dispatcher = deploy_default();
    dispatcher.external.set_token_uri(TOKEN_ID_2, "some_uri");
}

//
// burn cleanup
//

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_burn_cleans_up_token_uri() {
    let dispatcher = deploy_default();

    dispatcher.external.set_token_uri(TOKEN_ID, "custom_uri");

    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/custom_uri");

    // Burn the token
    dispatcher.external.burn(TOKEN_ID);

    // After burn, token should not exist
    dispatcher.metadata.token_uri(TOKEN_ID);
}

#[test]
fn test_transfer_preserves_token_uri() {
    let dispatcher = deploy_default();
    let recipient: ContractAddress = 'RECIPIENT'.try_into().unwrap();
    dispatcher.external.set_token_uri(TOKEN_ID, "custom_uri");
    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/custom_uri");

    start_cheat_caller_address(dispatcher.contract_address, OWNER);
    dispatcher.erc721.transfer_from(OWNER, recipient, TOKEN_ID);

    // URI should still be present after transfer
    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/custom_uri");
}

//
// Integration tests
//

#[test]
fn test_multiple_tokens_with_different_uris() {
    let dispatcher = deploy_default();

    dispatcher.external.mint(OWNER, TOKEN_ID_2);
    dispatcher.external.set_token_uri(TOKEN_ID, "token_1_uri");
    dispatcher.external.set_token_uri(TOKEN_ID_2, "token_2_uri");

    assert_eq!(dispatcher.metadata.token_uri(TOKEN_ID), "https://abc.com/token_1_uri");
    assert_eq!(dispatcher.metadata.token_uri(TOKEN_ID_2), "https://abc.com/token_2_uri");
}

#[test]
fn test_burn_one_token_preserves_other_uris() {
    let dispatcher = deploy_default();

    dispatcher.external.mint(OWNER, TOKEN_ID_2);
    dispatcher.external.set_token_uri(TOKEN_ID, "token_1_uri");
    dispatcher.external.set_token_uri(TOKEN_ID_2, "token_2_uri");

    // Burn first token
    start_cheat_caller_address(dispatcher.contract_address, OWNER);
    dispatcher.external.burn(TOKEN_ID);

    // Second token URI should be preserved
    assert_eq!(dispatcher.metadata.token_uri(TOKEN_ID_2), "https://abc.com/token_2_uri");
}

#[test]
fn test_mint_burn_remint_same_token_id() {
    let dispatcher = deploy_default();

    // Set URI for first mint
    dispatcher.external.set_token_uri(TOKEN_ID, "first_uri");
    assert_eq!(dispatcher.metadata.token_uri(TOKEN_ID), "https://abc.com/first_uri");

    // Burn token
    start_cheat_caller_address(dispatcher.contract_address, OWNER);
    dispatcher.external.burn(TOKEN_ID);

    // Remint same token ID
    dispatcher.external.mint(OWNER, TOKEN_ID);

    // URI should be empty (cleaned on burn, falls back to base + token_id)
    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/123");

    // Set new URI
    dispatcher.external.set_token_uri(TOKEN_ID, "second_uri");
    let uri = dispatcher.metadata.token_uri(TOKEN_ID);
    assert_eq!(uri, "https://abc.com/second_uri");
}

#[test]
fn test_multiple_events_emitted() {
    let mut spy = spy_events();
    let dispatcher = deploy_default();

    dispatcher.external.set_token_uri(TOKEN_ID, "uri_1");
    dispatcher.external.set_token_uri(TOKEN_ID, "uri_2");

    let expected_event_1 = ERC721URIStorageComponent::Event::MetadataUpdate(
        MetadataUpdate { token_id: TOKEN_ID },
    );
    let expected_event_2 = ERC721URIStorageComponent::Event::MetadataUpdate(
        MetadataUpdate { token_id: TOKEN_ID },
    );

    spy.assert_emitted_single(dispatcher.contract_address, expected_event_1);
    spy.assert_emitted_single(dispatcher.contract_address, expected_event_2);
}
