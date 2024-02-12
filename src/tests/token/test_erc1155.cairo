use integer::u256_from_felt252;
use openzeppelin::account::AccountComponent;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::introspection::src5;
use openzeppelin::introspection;
use openzeppelin::tests::mocks::account_mocks::{DualCaseAccountMock, CamelAccountMock};
use openzeppelin::tests::mocks::erc1155_mocks::DualCaseERC1155Mock;
use openzeppelin::tests::mocks::erc1155_receiver_mocks::{
    CamelERC1155ReceiverMock, SnakeERC1155ReceiverMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{
    DATA, ZERO, OWNER, RECIPIENT, SPENDER, OPERATOR, OTHER, TOKEN_ID, TOKEN_VALUE, PUBKEY,
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::ERC1155Component::ERC1155CamelImpl;
use openzeppelin::token::erc1155::ERC1155Component::{
    ERC1155Impl, ERC1155MetadataURIImpl, InternalImpl
};
use openzeppelin::token::erc1155::ERC1155Component::{TransferBatch, ApprovalForAll, TransferSingle};
use openzeppelin::token::erc1155::ERC1155Component;
use openzeppelin::token::erc1155;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::storage::StorageMapMemberAccessTrait;
use starknet::testing;

//
// Setup
//

type ComponentState = ERC1155Component::ComponentState<DualCaseERC1155Mock::ContractState>;

fn CONTRACT_STATE() -> DualCaseERC1155Mock::ContractState {
    DualCaseERC1155Mock::contract_state_for_testing()
}
fn COMPONENT_STATE() -> ComponentState {
    ERC1155Component::component_state_for_testing()
}

fn setup() -> (ComponentState, ContractAddress) {
    let mut state = COMPONENT_STATE();
    state.initializer("URI");

    let owner = setup_account();
    state.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, array![].span());
    utils::drop_event(ZERO());
    (state, owner)
}

fn setup_camel_receiver() -> ContractAddress {
    utils::deploy(CamelERC1155ReceiverMock::TEST_CLASS_HASH, array![])
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
// Initializers
//

#[test]
fn test_initialize() {
    let mut state = CONTRACT_STATE();
    state.erc1155.initializer("URI");

    assert(state.balance_of(OWNER(), TOKEN_ID) == 0, 'Balance should be zero');

    assert(state.src5.supports_interface(erc1155::interface::IERC1155_ID), 'Missing interface ID');
    assert(
        state.src5.supports_interface(erc1155::interface::IERC1155_METADATA_ID),
        'Missing interface ID'
    );
    assert(
        state.src5.supports_interface(introspection::interface::ISRC5_ID), 'Missing interface ID'
    );
}

//
// set_approval_for_all & _set_approval_for_all
//

#[test]
fn test_set_approval_for_all() {
    let mut state = CONTRACT_STATE();
    testing::set_caller_address(OWNER());

    assert(!state.is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    state.set_approval_for_all(OPERATOR(), true);
    assert_event_approval_for_all(OWNER(), OPERATOR(), true);

    assert(state.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');

    state.set_approval_for_all(OPERATOR(), false);
    assert_event_approval_for_all(OWNER(), OPERATOR(), false);

    assert(!state.is_approved_for_all(OWNER(), OPERATOR()), 'Approval not revoked correctly');
}

#[test]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let mut state = CONTRACT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(OWNER(), true);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let mut state = CONTRACT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(OWNER(), false);
}

//
// safe_transfer_from & safeTransferFrom
//

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_safe_transfer_from_to_non_receiver() {
    let (mut state, owner) = setup();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, recipient, token_id, value, DATA(true));
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_safeTransferFrom_to_non_receiver() {
    let (mut state, owner) = setup();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, recipient, token_id, value, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safe_transfer_from_to_zero() {
    let (mut state, owner) = setup();
    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, ZERO(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safeTransferFrom_to_zero() {
    let (mut state, owner) = setup();
    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, ZERO(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized caller',))]
fn test_safe_transfer_from_unauthorized() {
    let (mut state, owner) = setup();
    testing::set_caller_address(OTHER());
    state.safe_transfer_from(owner, RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized caller',))]
fn test_safeTransferFrom_unauthorized() {
    let (mut state, owner) = setup();
    testing::set_caller_address(OTHER());
    state.safeTransferFrom(owner, RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

//
// Helpers
//

fn assert_state_before_update_balances(
    owner: ContractAddress, recipient: ContractAddress, token_id: u256, value: u256
) {
    let state = CONTRACT_STATE();
    assert(state.balance_of(owner, token_id) == value, 'Balance of owner before');
    assert(state.balance_of(recipient, token_id) == 0, 'Balance of recipient before');
}

fn assert_state_after_update_balances(
    owner: ContractAddress, recipient: ContractAddress, token_id: u256, value: u256
) {
    let state = CONTRACT_STATE();
    assert(state.balance_of(owner, token_id) == 0, 'Balance of owner after');
    assert(state.balance_of(recipient, token_id) == value, 'Balance of recipient after');
}

fn assert_state_before_mint(recipient: ContractAddress, token_id: u256) {
    let state = CONTRACT_STATE();
    assert(state.balance_of(recipient, token_id) == 0, 'Balance of recipient before');
}

fn assert_state_after_mint(recipient: ContractAddress, token_id: u256, value: u256) {
    let state = CONTRACT_STATE();
    assert(state.balance_of(recipient, token_id) == value, 'Balance of recipient after');
}

fn assert_event_approval_for_all(
    owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ApprovalForAll>(ZERO()).unwrap();
    assert_eq!(event.account, owner);
    assert_eq!(event.operator, operator);
    assert_eq!(event.approved, approved);
    utils::assert_no_events_left(ZERO());

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(operator);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_transfer_single(
    from: ContractAddress, to: ContractAddress, token_id: u256, value: u256
) {
    let event = utils::pop_log::<TransferSingle>(ZERO()).unwrap();
    assert_eq!(event.from, from);
    assert_eq!(event.to, to);
    assert_eq!(event.id, token_id);
    assert_eq!(event.value, value);
    utils::assert_no_events_left(ZERO());

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    indexed_keys.append_serde(token_id);
    indexed_keys.append_serde(value);
    utils::assert_indexed_keys(event, indexed_keys.span());
}
