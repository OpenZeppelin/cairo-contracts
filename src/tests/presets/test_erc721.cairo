//use integer::BoundedInt;
use openzeppelin::account::AccountComponent;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::presets::ERC721::InternalImpl;
use openzeppelin::presets::ERC721;
use openzeppelin::tests::mocks::account_mocks::{DualCaseAccountMock, CamelAccountMock};
use openzeppelin::tests::mocks::erc721_receiver_mocks::{
    CamelERC721ReceiverMock, SnakeERC721ReceiverMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{
    ZERO, DATA, OWNER, SPENDER, RECIPIENT, OTHER, OPERATOR, PUBKEY, NAME, SYMBOL, DECIMALS, SUPPLY,
    VALUE
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721Component::InternalImpl as ERC721ComponentInternalTrait;
use openzeppelin::token::erc721::ERC721Component::{Approval, ApprovalForAll, Transfer};
use openzeppelin::token::erc721::ERC721Component::{ERC721CamelOnlyImpl, ERC721Impl};
use openzeppelin::token::erc721::ERC721Component::{ERC721MetadataImpl, ERC721MetadataCamelOnlyImpl};
use openzeppelin::token::erc721::interface::ERC721ABI;
use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::testing;


// Token IDs
const TOKEN_1: u256 = 1;
const TOKEN_2: u256 = 2;
const TOKEN_3: u256 = 3;
const NONEXISTENT: u256 = 9898;

const TOKENS_LEN: u256 = 3;

// Token URIs
const URI_1: felt252 = 'URI_1';
const URI_2: felt252 = 'URI_2';
const URI_3: felt252 = 'URI_3';

//
// Setup
//

fn setup_dispatcher_with_event() -> ERC721ABIDispatcher {
    let mut calldata = array![];
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3];
    let mut token_uris = array![URI_1, URI_2, URI_3];

    calldata.append_serde(NAME);
    calldata.append_serde(SYMBOL);
    calldata.append_serde(OWNER());
    calldata.append_serde(token_ids);
    calldata.append_serde(token_uris);

    let address = utils::deploy(ERC721::TEST_CLASS_HASH, calldata);
    ERC721ABIDispatcher { contract_address: address }
}

fn setup_dispatcher() -> ERC721ABIDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    let mut events = TOKENS_LEN;
    loop {
        if events == 0 {
            break ();
        }
        utils::drop_event(dispatcher.contract_address);
        events -= 1;
    };
    dispatcher
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(SnakeERC721ReceiverMock::TEST_CLASS_HASH, array![])
}

fn setup_camel_receiver() -> ContractAddress {
    utils::deploy(CamelERC721ReceiverMock::TEST_CLASS_HASH, array![])
}

fn setup_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(DualCaseAccountMock::TEST_CLASS_HASH, calldata)
}

fn setup_camel_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(CamelAccountMock::TEST_CLASS_HASH, calldata)
}

//
// _mint_assets
//

#[test]
#[available_gas(2000000000)]
fn test__mint_assets() {
    let mut state = ERC721::contract_state_for_testing();

    let token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3];
    let token_uris = array![URI_1, URI_2, URI_3];
    let mut ids_span = token_ids.span();
    let mut uris_span = token_uris.span();

    state._mint_assets(OWNER(), token_ids, token_uris);

    assert(TOKENS_LEN.into() == state.erc721.balance_of(OWNER()), 'Should equal IDs length');

    loop {
        if ids_span.len() == 0 {
            break ();
        }
        let id = *ids_span.pop_front().unwrap();
        let uri = *uris_span.pop_front().unwrap();
        assert(state.erc721.owner_of(id) == OWNER(), 'Should be owned by RECIPIENT');
        assert(state.erc721.token_uri(id) == uri, 'Should equal correct URI');
    };
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Array lengths do not match',))]
fn test__mint_assets_mismatched_arrays_1() {
    let mut state = ERC721::contract_state_for_testing();

    let token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3];
    let short_uris = array![URI_1, URI_2];
    state._mint_assets(OWNER(), token_ids, short_uris);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Array lengths do not match',))]
fn test__mint_assets_mismatched_arrays_2() {
    let mut state = ERC721::contract_state_for_testing();

    let short_ids = array![TOKEN_1, TOKEN_2];
    let token_uris = array![URI_1, URI_2, URI_3];
    state._mint_assets(OWNER(), short_ids, token_uris);
}

//
// Getters
//

#[test]
#[available_gas(20000000)]
fn test_balance_of() {
    let dispatcher = setup_dispatcher();
    assert(dispatcher.balance_of(OWNER()) == TOKENS_LEN, 'Should return balance');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid account', 'ENTRYPOINT_FAILED'))]
fn test_balance_of_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.balance_of(ZERO());
}

#[test]
#[available_gas(20000000)]
fn test_owner_of() {
    let dispatcher = setup_dispatcher();
    assert(dispatcher.owner_of(TOKEN_1) == OWNER(), 'Should return owner');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_owner_of_non_minted() {
    let dispatcher = setup_dispatcher();
    dispatcher.owner_of(7);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_token_uri_non_minted() {
    let dispatcher = setup_dispatcher();
    dispatcher.token_uri(7);
}

#[test]
#[available_gas(20000000)]
fn test_get_approved() {
    let dispatcher = setup_dispatcher();
    let spender = SPENDER();
    let token_id = TOKEN_1;

    assert(dispatcher.get_approved(token_id) == ZERO(), 'Should return non-approval');

    testing::set_contract_address(OWNER());

    dispatcher.approve(spender, token_id);
    assert(dispatcher.get_approved(token_id) == spender, 'Should return approval');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_get_approved_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.get_approved(7);
}

//
// approve
//

#[test]
#[available_gas(20000000)]
fn test_approve_from_owner() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), TOKEN_1);
    assert_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), TOKEN_1);

    assert(dispatcher.get_approved(TOKEN_1) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(20000000)]
fn test_approve_from_operator() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.approve(SPENDER(), TOKEN_1);
    assert_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), TOKEN_1);

    assert(dispatcher.get_approved(TOKEN_1) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_approve_from_unauthorized() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(OTHER());
    dispatcher.approve(SPENDER(), TOKEN_1);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: approval to owner', 'ENTRYPOINT_FAILED'))]
fn test_approve_to_owner() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    dispatcher.approve(OWNER(), TOKEN_1);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_approve_nonexistent() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), NONEXISTENT);
}

//
// set_approval_for_all
//

#[test]
#[available_gas(20000000)]
fn test_set_approval_for_all() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());

    assert(!dispatcher.is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    dispatcher.set_approval_for_all(OPERATOR(), true);
    assert_event_approval_for_all(dispatcher.contract_address, OWNER(), OPERATOR(), true);

    assert(dispatcher.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');

    dispatcher.set_approval_for_all(OPERATOR(), false);
    assert_event_approval_for_all(dispatcher.contract_address, OWNER(), OPERATOR(), false);

    assert(!dispatcher.is_approved_for_all(OWNER(), OPERATOR()), 'Approval not revoked correctly');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval', 'ENTRYPOINT_FAILED'))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OWNER(), true);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval', 'ENTRYPOINT_FAILED'))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OWNER(), false);
}

//
// transfer_from & transferFrom
//

#[test]
#[available_gas(20000000)]
fn test_transfer_from_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    // set approval to check reset
    testing::set_contract_address(OWNER());
    dispatcher.approve(OTHER(), token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);
    assert(dispatcher.get_approved(token_id) == OTHER(), 'Approval not implicitly reset');

    testing::set_contract_address(owner);
    dispatcher.transfer_from(owner, recipient, token_id);
    assert_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();
    // set approval to check reset
    testing::set_contract_address(owner);
    dispatcher.approve(OTHER(), token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);
    assert(dispatcher.get_approved(token_id) == OTHER(), 'Approval not implicitly reset');

    dispatcher.transferFrom(owner, recipient, token_id);
    assert_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: wrong sender', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.transfer_from(ZERO(), RECIPIENT(), TOKEN_1);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: wrong sender', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.transferFrom(ZERO(), RECIPIENT(), TOKEN_1);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_to_zero() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transfer_from(OWNER(), ZERO(), TOKEN_1);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_to_zero() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    dispatcher.transferFrom(OWNER(), ZERO(), TOKEN_1);
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_to_owner() {
    let dispatcher = setup_dispatcher();

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);

    testing::set_contract_address(OWNER());
    dispatcher.transfer_from(OWNER(), OWNER(), TOKEN_1);
    assert_event_transfer(dispatcher.contract_address, OWNER(), OWNER(), TOKEN_1);

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_to_owner() {
    let dispatcher = setup_dispatcher();

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);

    testing::set_contract_address(OWNER());
    dispatcher.transferFrom(OWNER(), OWNER(), TOKEN_1);
    assert_event_transfer(dispatcher.contract_address, OWNER(), OWNER(), TOKEN_1);

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_approved() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    testing::set_contract_address(owner);
    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transfer_from(owner, recipient, token_id);
    assert_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_approved() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    testing::set_contract_address(owner);
    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transferFrom(owner, recipient, token_id);
    assert_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    testing::set_contract_address(owner);
    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transfer_from(owner, recipient, token_id);
    assert_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    testing::set_contract_address(owner);
    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transferFrom(owner, recipient, token_id);
    assert_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_1);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transferFrom(OWNER(), RECIPIENT(), TOKEN_1);
}

//
// safe_transfer_from & safeTransferFrom
//

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_account() {
    let dispatcher = setup_dispatcher();
    let account = setup_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, account, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_account() {
    let dispatcher = setup_dispatcher();
    let account = setup_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    testing::set_contract_address(owner);
    dispatcher.safeTransferFrom(owner, account, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_account_camel() {
    let dispatcher = setup_dispatcher();
    let account = setup_camel_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, account, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_account_camel() {
    let dispatcher = setup_dispatcher();
    let account = setup_camel_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    testing::set_contract_address(owner);
    dispatcher.safeTransferFrom(owner, account, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_receiver() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_receiver() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_receiver_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_receiver_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_receiver_failure() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_receiver_failure() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    testing::set_contract_address(owner);
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_receiver_failure_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_receiver_failure_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    testing::set_contract_address(owner);
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_non_receiver() {
    let dispatcher = setup_dispatcher();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_1;
    let owner = OWNER();

    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, recipient, token_id, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_non_receiver() {
    let dispatcher = setup_dispatcher();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_1;
    let owner = OWNER();

    testing::set_contract_address(owner);
    dispatcher.safeTransferFrom(owner, recipient, token_id, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: wrong sender', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.safe_transfer_from(ZERO(), RECIPIENT(), TOKEN_1, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: wrong sender', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.safeTransferFrom(ZERO(), RECIPIENT(), TOKEN_1, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_zero() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.safe_transfer_from(OWNER(), ZERO(), TOKEN_1, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_zero() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.safeTransferFrom(OWNER(), ZERO(), TOKEN_1, DATA(true));
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_receiver();

    testing::set_contract_address(OWNER());
    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safe_transfer_from(receiver, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_receiver();

    testing::set_contract_address(OWNER());
    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safeTransferFrom(receiver, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_owner_camel() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_camel_receiver();

    testing::set_contract_address(OWNER());
    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safe_transfer_from(receiver, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_owner_camel() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_camel_receiver();

    testing::set_contract_address(OWNER());
    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safeTransferFrom(receiver, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_for_all_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_for_all_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    testing::set_contract_address(owner);
    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_1, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.safeTransferFrom(OWNER(), RECIPIENT(), TOKEN_1, DATA(true));
}

//
// Helpers
//

fn assert_state_before_transfer(
    dispatcher: ERC721ABIDispatcher,
    owner: ContractAddress,
    recipient: ContractAddress,
    token_id: u256
) {
    assert(dispatcher.owner_of(token_id) == owner, 'Ownership before');
    assert(dispatcher.balance_of(owner) == TOKENS_LEN, 'Balance of owner before');
    assert(dispatcher.balance_of(recipient) == 0, 'Balance of recipient before');
}

fn assert_state_after_transfer(
    dispatcher: ERC721ABIDispatcher,
    owner: ContractAddress,
    recipient: ContractAddress,
    token_id: u256
) {
    assert(dispatcher.owner_of(token_id) == recipient, 'Ownership after');
    assert(dispatcher.balance_of(owner) == TOKENS_LEN - 1, 'Balance of owner after');
    assert(dispatcher.balance_of(recipient) == 1, 'Balance of recipient after');
    assert(dispatcher.get_approved(token_id) == ZERO(), 'Approval not implicitly reset');
}

fn assert_state_transfer_to_self(
    dispatcher: ERC721ABIDispatcher,
    target: ContractAddress,
    token_id: u256,
    token_balance: u256
) {
    assert(dispatcher.owner_of(token_id) == target, 'Ownership before');
    assert(dispatcher.balance_of(target) == token_balance, 'Balance of owner before');   
}

fn assert_event_approval_for_all(
    contract: ContractAddress, owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ApprovalForAll>(contract).unwrap();
    assert(event.owner == owner, 'Invalid `owner`');
    assert(event.operator == operator, 'Invalid `operator`');
    assert(event.approved == approved, 'Invalid `approved`');
    utils::assert_no_events_left(contract);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(operator);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_approval(
    contract: ContractAddress, owner: ContractAddress, approved: ContractAddress, token_id: u256
) {
    let event = utils::pop_log::<Approval>(contract).unwrap();
    assert(event.owner == owner, 'Invalid `owner`');
    assert(event.approved == approved, 'Invalid `approved`');
    assert(event.token_id == token_id, 'Invalid `token_id`');
    utils::assert_no_events_left(contract);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(approved);
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, token_id: u256
) {
    let event = utils::pop_log::<Transfer>(contract).unwrap();
    assert(event.from == from, 'Invalid `from`');
    assert(event.to == to, 'Invalid `to`');
    assert(event.token_id == token_id, 'Invalid `token_id`');
    utils::assert_no_events_left(contract);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

