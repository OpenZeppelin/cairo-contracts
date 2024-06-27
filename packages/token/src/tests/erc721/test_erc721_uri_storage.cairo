use openzeppelin::tests::mocks:erc721_uri_storage_mocks::ERC721URIstorageMock;
use openzeppelin::tests::utils::constants::{
    DATA, ZERO, OWNER, CALLER, RECIPIENT, SPENDER, OPERATOR, OTHER, NAME, SYMBOL, TOKEN_ID,
    TOKEN_ID_2, PUBKEY, BASE_URI, BASE_URI_2
};
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::introspection::src5;
use openzeppelin::introspection;
use openzeppelin::token::erc721::ERC721Component::{ERC721Impl, ERC721MetadataImpl, InternalImpl};
use openzeppelin::token::erc721::ERC721Component;
use openzeppelin::token::erc721::extensions::ERC721URIstorageComponent;
use openzeppelin::token::erc721::extensions::ERC721URIstorageComponent::{ERC721URIstorageImpl,InternalImpl};

use openzeppelin::token::erc721::interface::IERC721;
use openzeppelin::token::erc721;
use openzeppelin::tests::utils;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::storage::{StorageMapMemberAccessTrait, StorageMemberAccessTrait};
use starknet::testing;



//
// Setup
//

type ComponentState = ERC721URIstorageComponent::ComponentState<ERC721URIstorageMock::ContractState>;

fn CONTRACT_STATE() -> ERC721URIstorageMock::ContractState {
    ERC721URIstorageMock::contract_state_for_testing()
}
fn COMPONENT_STATE() -> ComponentState {
    ERC721URIstorageComponent::component_state_for_testing()
}

//constructor is inside only
fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    let mock_state=CONTRACT_STATE();
    mock_state.erc721.initializer(NAME(), SYMBOL(), BASE_URI());
    mock_state.erc721.mint(OWNER(),TOKEN_ID);
    utils::drop_event(ZERO());
    state
}

//check token_uri for minted ones are by default empty
#[test]
fn test_token_uri() {
    let state = setup();
    let uri = state.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI(), TOKEN_ID);
    assert_eq!(uri, expected);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_token_uri_non_minted() {
    let state = setup();
    state.token_uri(7);
}

//check setter (set_token_uri)
#[test]
fn test_set_token_uri(){
    let state=setup();
    
    state.set_token_uri(TOKEN_ID,BASE_URI_2);
    assert_only_event_metadata_update(TOKEN_ID);
    
    let expected= format!("{}{}{}", BASE_URI(), TOKEN_ID,BASE_URI_2);
    let uri=state.token_uri(TOKEN_ID);
    
    assert_eq!(uri,expected);
}





//
// Helpers
//
fn assert_event_metadata_update(contract:ContractAddress,token_id:u256){
    let event=utils::pop_log::<ERC721URIstorageComponent::Event>(contract).unwrap();
    let expected=ERC721URIstorageComponent::Event::MetadataUpdate(
        MetadataUpdate{token_id}
    );
    assert!(event==expected);

    //check indexed keys
    ley mut indexed_keys=array![];
    indexed_keys.append_serde(selector!("MetadataUpdate"));
    indexed_keys.append_serde(token_id);
    utisl:::assert_indexed_keys(event,indexed_keys.span())
}

fn assert_only_event_metadata_update(
    contract: ContractAddress, token_id : u256
) {
    assert_event_metadata_update(contract, token_id);
    utils::assert_no_events_left(contract);
}