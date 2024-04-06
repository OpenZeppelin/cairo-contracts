use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::presets::ERC721Upgradeable::InternalImpl;
use openzeppelin::presets::ERC721Upgradeable;
use openzeppelin::presets::interfaces::{
    IERC721UpgradeableDispatcher, IERC721UpgradeableDispatcherTrait
};
use openzeppelin::tests::access::test_ownable::assert_event_ownership_transferred;
use openzeppelin::tests::mocks::account_mocks::{DualCaseAccountMock, CamelAccountMock};
use openzeppelin::tests::mocks::erc721_mocks::SnakeERC721Mock;
use openzeppelin::tests::mocks::erc721_receiver_mocks::{
    CamelERC721ReceiverMock, SnakeERC721ReceiverMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::upgrades::test_upgradeable::assert_only_event_upgraded;
use openzeppelin::tests::utils::constants::{
    ZERO, DATA, OWNER, SPENDER, RECIPIENT, OTHER, OPERATOR, CLASS_HASH_ZERO, PUBKEY, NAME, SYMBOL,
    BASE_URI
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721Component::{Approval, ApprovalForAll, Transfer};
use openzeppelin::token::erc721::ERC721Component::{ERC721Impl};
use openzeppelin::token::erc721::ERC721Component;
use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721_ID, IERC721_METADATA_ID};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing;
use starknet::{ContractAddress, ClassHash};


// Token IDs
const TOKEN_1: u256 = 1;
const TOKEN_2: u256 = 2;
const TOKEN_3: u256 = 3;
const NONEXISTENT: u256 = 9898;

const TOKENS_LEN: u256 = 3;

fn V2_CLASS_HASH() -> ClassHash {
    SnakeERC721Mock::TEST_CLASS_HASH.try_into().unwrap()
}

//
// Setup
//

fn setup_dispatcher_with_event() -> IERC721UpgradeableDispatcher {
    let mut calldata = array![];
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3];

    // Set caller as `OWNER`
    testing::set_contract_address(OWNER());

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(token_ids);
    calldata.append_serde(OWNER());

    let address = utils::deploy(ERC721Upgradeable::TEST_CLASS_HASH, calldata);
    IERC721UpgradeableDispatcher { contract_address: address }
}

fn setup_dispatcher() -> IERC721UpgradeableDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    // `OwnershipTransferred` + `Transfer`s
    utils::drop_events(dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);
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
fn test__mint_assets() {
    let mut state = ERC721Upgradeable::contract_state_for_testing();
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3].span();

    state._mint_assets(OWNER(), token_ids);
    assert_eq!(state.erc721.balance_of(OWNER()), TOKENS_LEN);

    loop {
        if token_ids.len() == 0 {
            break;
        }
        let id = *token_ids.pop_front().unwrap();
        assert_eq!(state.erc721.owner_of(id), OWNER());
    };
}

//
// constructor
//

#[test]
fn test_constructor() {
    let dispatcher = setup_dispatcher_with_event();

    // Check interface registration
    let mut interface_ids = array![ISRC5_ID, IERC721_ID, IERC721_METADATA_ID];
    loop {
        let id = interface_ids.pop_front().unwrap();
        if interface_ids.len() == 0 {
            break;
        }
        let supports_interface = dispatcher.supports_interface(id);
        assert!(supports_interface);
    };

    // Check token balance and owner
    let mut tokens = array![TOKEN_1, TOKEN_2, TOKEN_3];
    assert_eq!(dispatcher.balance_of(OWNER()), TOKENS_LEN);

    loop {
        let token = tokens.pop_front().unwrap();
        if tokens.len() == 0 {
            break;
        }
        let current_owner = dispatcher.owner_of(token);
        assert_eq!(current_owner, OWNER());
    };
}

#[test]
fn test_constructor_events() {
    let dispatcher = setup_dispatcher_with_event();
    let mut tokens = array![TOKEN_1, TOKEN_2, TOKEN_3];

    assert_event_ownership_transferred(dispatcher.contract_address, ZERO(), OWNER());
    loop {
        let token = tokens.pop_front().unwrap();
        if tokens.len() == 0 {
            // Includes event queue check
            assert_only_event_transfer(dispatcher.contract_address, ZERO(), OWNER(), token);
            break;
        }
        assert_event_transfer(dispatcher.contract_address, ZERO(), OWNER(), token);
    };
}

//
// Getters
//

#[test]
fn test_balance_of() {
    let dispatcher = setup_dispatcher();
    assert_eq!(dispatcher.balance_of(OWNER()), TOKENS_LEN);
}

#[test]
#[should_panic(expected: ('ERC721: invalid account', 'ENTRYPOINT_FAILED'))]
fn test_balance_of_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.balance_of(ZERO());
}

#[test]
fn test_owner_of() {
    let dispatcher = setup_dispatcher();
    assert_eq!(dispatcher.owner_of(TOKEN_1), OWNER());
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_owner_of_non_minted() {
    let dispatcher = setup_dispatcher();
    dispatcher.owner_of(7);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_token_uri_non_minted() {
    let dispatcher = setup_dispatcher();
    dispatcher.token_uri(7);
}

#[test]
fn test_token_uri() {
    let dispatcher = setup_dispatcher();

    let uri = dispatcher.token_uri(TOKEN_1);
    let expected = format!("{}{}", BASE_URI(), TOKEN_1);
    assert_eq!(uri, expected);
}

#[test]
fn test_get_approved() {
    let dispatcher = setup_dispatcher();
    let spender = SPENDER();
    let token_id = TOKEN_1;

    let approved = dispatcher.get_approved(token_id);
    assert!(approved.is_zero());

    dispatcher.approve(spender, token_id);
    let approved = dispatcher.get_approved(token_id);
    assert_eq!(approved, spender);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_get_approved_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.get_approved(NONEXISTENT);
}

//
// approve
//

#[test]
fn test_approve_from_owner() {
    let dispatcher = setup_dispatcher();

    dispatcher.approve(SPENDER(), TOKEN_1);
    assert_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), TOKEN_1);

    let approved = dispatcher.get_approved(TOKEN_1);
    assert_eq!(approved, SPENDER());
}

#[test]
fn test_approve_from_operator() {
    let dispatcher = setup_dispatcher();

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.approve(SPENDER(), TOKEN_1);
    assert_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), TOKEN_1);

    let approved = dispatcher.get_approved(TOKEN_1);
    assert_eq!(approved, SPENDER());
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_approve_from_unauthorized() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(OTHER());
    dispatcher.approve(SPENDER(), TOKEN_1);
}

#[test]
#[should_panic(expected: ('ERC721: approval to owner', 'ENTRYPOINT_FAILED'))]
fn test_approve_to_owner() {
    let dispatcher = setup_dispatcher();

    dispatcher.approve(OWNER(), TOKEN_1);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_approve_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.approve(SPENDER(), NONEXISTENT);
}

//
// set_approval_for_all
//

#[test]
fn test_set_approval_for_all() {
    let dispatcher = setup_dispatcher();

    let is_not_approved_for_all = !dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_not_approved_for_all);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    assert_event_approval_for_all(dispatcher.contract_address, OWNER(), OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);

    dispatcher.set_approval_for_all(OPERATOR(), false);
    assert_event_approval_for_all(dispatcher.contract_address, OWNER(), OPERATOR(), false);

    let is_not_approved_for_all = !dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_not_approved_for_all);
}

#[test]
#[should_panic(expected: ('ERC721: self approval', 'ENTRYPOINT_FAILED'))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let dispatcher = setup_dispatcher();
    dispatcher.set_approval_for_all(OWNER(), true);
}

#[test]
#[should_panic(expected: ('ERC721: self approval', 'ENTRYPOINT_FAILED'))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let dispatcher = setup_dispatcher();
    dispatcher.set_approval_for_all(OWNER(), false);
}

//
// transfer_from & transferFrom
//

#[test]
fn test_transfer_from_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    // set approval to check reset
    dispatcher.approve(OTHER(), token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    let approved = dispatcher.get_approved(token_id);
    assert_eq!(approved, OTHER());

    dispatcher.transfer_from(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
fn test_transferFrom_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    // set approval to check reset
    dispatcher.approve(OTHER(), token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    let approved = dispatcher.get_approved(token_id);
    assert_eq!(approved, OTHER());

    dispatcher.transferFrom(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), NONEXISTENT);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.transferFrom(OWNER(), RECIPIENT(), NONEXISTENT);
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_to_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.transfer_from(OWNER(), ZERO(), TOKEN_1);
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_to_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.transferFrom(OWNER(), ZERO(), TOKEN_1);
}

#[test]
fn test_transfer_from_to_owner() {
    let dispatcher = setup_dispatcher();

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
    dispatcher.transfer_from(OWNER(), OWNER(), TOKEN_1);
    assert_only_event_transfer(dispatcher.contract_address, OWNER(), OWNER(), TOKEN_1);

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
}

#[test]
fn test_transferFrom_to_owner() {
    let dispatcher = setup_dispatcher();

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
    dispatcher.transferFrom(OWNER(), OWNER(), TOKEN_1);
    assert_only_event_transfer(dispatcher.contract_address, OWNER(), OWNER(), TOKEN_1);

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
}

#[test]
fn test_transfer_from_approved() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transfer_from(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
fn test_transferFrom_approved() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transferFrom(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
fn test_transfer_from_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transfer_from(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
fn test_transferFrom_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transferFrom(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_1);
}

#[test]
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
fn test_safe_transfer_from_to_account() {
    let dispatcher = setup_dispatcher();
    let account = setup_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    dispatcher.safe_transfer_from(owner, account, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
fn test_safeTransferFrom_to_account() {
    let dispatcher = setup_dispatcher();
    let account = setup_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    dispatcher.safeTransferFrom(owner, account, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
fn test_safe_transfer_from_to_account_camel() {
    let dispatcher = setup_dispatcher();
    let account = setup_camel_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    dispatcher.safe_transfer_from(owner, account, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
fn test_safeTransferFrom_to_account_camel() {
    let dispatcher = setup_dispatcher();
    let account = setup_camel_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    dispatcher.safeTransferFrom(owner, account, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
fn test_safe_transfer_from_to_receiver() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_to_receiver() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safe_transfer_from_to_receiver_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_to_receiver_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_receiver_failure() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_receiver_failure() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(false));
}

#[test]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_receiver_failure_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_receiver_failure_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(false));
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_non_receiver() {
    let dispatcher = setup_dispatcher();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safe_transfer_from(owner, recipient, token_id, DATA(true));
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_non_receiver() {
    let dispatcher = setup_dispatcher();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safeTransferFrom(owner, recipient, token_id, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), NONEXISTENT, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.safeTransferFrom(OWNER(), RECIPIENT(), NONEXISTENT, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.safe_transfer_from(OWNER(), ZERO(), TOKEN_1, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.safeTransferFrom(OWNER(), ZERO(), TOKEN_1, DATA(true));
}

#[test]
fn test_safe_transfer_from_to_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_receiver();

    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safe_transfer_from(receiver, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
fn test_safeTransferFrom_to_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_receiver();

    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safeTransferFrom(receiver, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
fn test_safe_transfer_from_to_owner_camel() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_camel_receiver();

    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safe_transfer_from(receiver, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
fn test_safeTransferFrom_to_owner_camel() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_camel_receiver();

    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safeTransferFrom(receiver, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
fn test_safe_transfer_from_approved() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_approved() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safe_transfer_from_approved_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_approved_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safe_transfer_from_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safe_transfer_from_approved_for_all_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_approved_for_all_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_1, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.safeTransferFrom(OWNER(), RECIPIENT(), TOKEN_1, DATA(true));
}

//
// transfer_ownership & transferOwnership
//

#[test]
fn test_transfer_ownership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transfer_ownership(OTHER());

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), OTHER());
    assert_eq!(dispatcher.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_to_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transfer_ownership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_from_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.transfer_ownership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transfer_ownership(OTHER());
}

#[test]
fn test_transferOwnership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transferOwnership(OTHER());

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), OTHER());
    assert_eq!(dispatcher.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_to_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transferOwnership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_from_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.transferOwnership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transferOwnership(OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
fn test_renounce_ownership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.renounce_ownership();

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), ZERO());
    assert!(dispatcher.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_renounce_ownership_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.renounce_ownership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_renounce_ownership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.renounce_ownership();
}

#[test]
fn test_renounceOwnership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.renounceOwnership();

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), ZERO());
    assert!(dispatcher.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_renounceOwnership_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.renounceOwnership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_renounceOwnership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.renounceOwnership();
}

//
// upgrade
//

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_unauthorized() {
    let v1 = setup_dispatcher();
    testing::set_contract_address(OTHER());
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_with_class_hash_zero() {
    let v1 = setup_dispatcher();

    testing::set_contract_address(OWNER());
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
fn test_upgraded_event() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.upgrade(v2_class_hash);

    assert_only_event_upgraded(v1.contract_address, v2_class_hash);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_v2_missing_camel_selector() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.upgrade(v2_class_hash);

    let dispatcher = ERC721ABIDispatcher { contract_address: v1.contract_address };
    dispatcher.ownerOf(TOKEN_1);
}

#[test]
fn test_state_persists_after_upgrade() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.transferFrom(OWNER(), RECIPIENT(), TOKEN_1);

    // Check RECIPIENT balance v1
    let camel_balance = v1.balanceOf(RECIPIENT());
    assert_eq!(camel_balance, 1);

    v1.upgrade(v2_class_hash);

    // Check RECIPIENT balance v2
    let v2 = ERC721ABIDispatcher { contract_address: v1.contract_address };
    let snake_balance = v2.balance_of(RECIPIENT());
    assert_eq!(snake_balance, camel_balance);
}

//
// Helpers
//

fn assert_state_before_transfer(
    dispatcher: IERC721UpgradeableDispatcher,
    owner: ContractAddress,
    recipient: ContractAddress,
    token_id: u256
) {
    assert_eq!(dispatcher.owner_of(token_id), owner);
    assert_eq!(dispatcher.balance_of(owner), TOKENS_LEN);
    assert!(dispatcher.balance_of(recipient).is_zero());
}

fn assert_state_after_transfer(
    dispatcher: IERC721UpgradeableDispatcher,
    owner: ContractAddress,
    recipient: ContractAddress,
    token_id: u256
) {
    let current_owner = dispatcher.owner_of(token_id);
    assert_eq!(current_owner, recipient);
    assert_eq!(dispatcher.balance_of(owner), TOKENS_LEN - 1);
    assert_eq!(dispatcher.balance_of(recipient), 1);

    let approved = dispatcher.get_approved(token_id);
    assert!(approved.is_zero());
}

fn assert_state_transfer_to_self(
    dispatcher: IERC721UpgradeableDispatcher,
    target: ContractAddress,
    token_id: u256,
    token_balance: u256
) {
    assert_eq!(dispatcher.owner_of(token_id), target);
    assert_eq!(dispatcher.balance_of(target), token_balance);
}

fn assert_event_approval_for_all(
    contract: ContractAddress, owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::ApprovalForAll(
        ApprovalForAll { owner, operator, approved, }
    );
    assert!(event == expected);
    utils::assert_no_events_left(contract);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("ApprovalForAll"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(operator);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_approval(
    contract: ContractAddress, owner: ContractAddress, approved: ContractAddress, token_id: u256
) {
    let event = utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::Approval(Approval { owner, approved, token_id });
    assert!(event == expected);
    utils::assert_no_events_left(contract);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Approval"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(approved);
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, token_id: u256
) {
    let event = utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::Transfer(Transfer { from, to, token_id });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Transfer"));
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, value: u256
) {
    assert_event_transfer(contract, from, to, value);
    utils::assert_no_events_left(contract);
}
