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
    DATA, ZERO, OWNER, RECIPIENT, SPENDER, OPERATOR, OTHER, NAME, SYMBOL, URI, TOKEN_ID,
    TOKEN_VALUE, PUBKEY,
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::ERC1155Component::ERC1155CamelOnlyImpl;
use openzeppelin::token::erc1155::ERC1155Component::{
    ERC1155Impl, ERC1155MetadataImpl, InternalImpl
};
use openzeppelin::token::erc1155::ERC1155Component::{Approval, ApprovalForAll, Transfer};
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

fn STATE() -> DualCaseERC1155Mock::ContractState {
    DualCaseERC1155Mock::contract_state_for_testing()
}

fn setup() -> DualCaseERC1155Mock::ContractState {
    let mut state = STATE();
    state.erc1155.initializer(NAME, SYMBOL);
    state.erc1155._mint(OWNER(), TOKEN_ID, TOKEN_VALUE);
    utils::drop_event(ZERO());
    state
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(SnakeERC1155ReceiverMock::TEST_CLASS_HASH, array![])
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
#[available_gas(20000000)]
fn test_initialize() {
    let mut state = STATE();
    state.erc1155.initializer(NAME, SYMBOL);

    assert(state.erc1155.name() == NAME, 'Name should be NAME');
    assert(state.erc1155.symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(state.erc1155.balance_of(OWNER(), TOKEN_ID) == 0, 'Balance should be zero');

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
// Getters
//

#[test]
#[available_gas(20000000)]
fn test_balance_of() {
    let state = setup();
    assert(state.erc1155.balance_of(OWNER(), TOKEN_ID) == 1, 'Should return balance');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid account',))]
fn test_balance_of_zero() {
    let state = setup();
    state.erc1155.balance_of(ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid token ID',))]
fn test_uri_non_minted() {
    let state = setup();
    state.erc1155.uri(u256_from_felt252(7));
}

//
// set_approval_for_all & _set_approval_for_all
//

#[test]
#[available_gas(20000000)]
fn test_set_approval_for_all() {
    let mut state = STATE();
    testing::set_caller_address(OWNER());

    assert(!state.erc1155.is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    state.erc1155.set_approval_for_all(OPERATOR(), true);
    assert_event_approval_for_all(OWNER(), OPERATOR(), true);

    assert(
        state.erc1155.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly'
    );

    state.erc1155.set_approval_for_all(OPERATOR(), false);
    assert_event_approval_for_all(OWNER(), OPERATOR(), false);

    assert(
        !state.erc1155.is_approved_for_all(OWNER(), OPERATOR()), 'Approval not revoked correctly'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let mut state = STATE();
    testing::set_caller_address(OWNER());
    state.erc1155.set_approval_for_all(OWNER(), true);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let mut state = STATE();
    testing::set_caller_address(OWNER());
    state.erc1155.set_approval_for_all(OWNER(), false);
}

#[test]
#[available_gas(20000000)]
fn test__set_approval_for_all() {
    let mut state = STATE();
    assert(!state.erc1155.is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    state.erc1155._set_approval_for_all(OWNER(), OPERATOR(), true);
    assert_event_approval_for_all(OWNER(), OPERATOR(), true);

    assert(
        state.erc1155.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly'
    );

    state.erc1155._set_approval_for_all(OWNER(), OPERATOR(), false);
    assert_event_approval_for_all(OWNER(), OPERATOR(), false);

    assert(
        !state.erc1155.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test__set_approval_for_all_owner_equal_operator_true() {
    let mut state = STATE();
    state.erc1155._set_approval_for_all(OWNER(), OWNER(), true);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test__set_approval_for_all_owner_equal_operator_false() {
    let mut state = STATE();
    state.erc1155._set_approval_for_all(OWNER(), OWNER(), false);
}

//
// transfer_from & transferFrom
//

#[test]
#[available_gas(20000000)]
fn test_update_balances_from_owner() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();
    let recipient = RECIPIENT();
    utils::drop_event(ZERO());

    assert_state_before_update_balances(owner, recipient, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.transfer_from(owner, recipient, token_id, value);
    assert_event_update_balances(owner, recipient, token_id, value);

    assert_state_after_update_balances(owner, recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_update_balancesFrom_owner() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();
    let recipient = RECIPIENT();
    utils::drop_event(ZERO());

    assert_state_before_update_balances(owner, recipient, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.transferFrom(owner, recipient, token_id, value);
    assert_event_update_balances(owner, recipient, token_id, value);

    assert_state_after_update_balances(owner, recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid token ID',))]
fn test_update_balances_from_nonexistent() {
    let mut state = STATE();
    state.erc1155.transfer_from(ZERO(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid token ID',))]
fn test_update_balancesFrom_nonexistent() {
    let mut state = STATE();
    state.erc1155.transferFrom(ZERO(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_update_balances_from_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc1155.transfer_from(OWNER(), ZERO(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_update_balancesFrom_to_zero() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    state.erc1155.transferFrom(OWNER(), ZERO(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(20000000)]
fn test_update_balances_from_to_owner() {
    let mut state = setup();

    assert(state.erc1155.balance_of(OWNER(), TOKEN_ID) == 1, 'Balance of owner before');

    testing::set_caller_address(OWNER());
    state.erc1155.transfer_from(OWNER(), OWNER(), TOKEN_ID, TOKEN_VALUE);
    assert_event_update_balances(OWNER(), OWNER(), TOKEN_ID, TOKEN_VALUE);

    assert(state.erc1155.balance_of(OWNER(), TOKEN_ID) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_update_balancesFrom_to_owner() {
    let mut state = setup();

    assert(state.erc1155.balance_of(OWNER(), TOKEN_ID) == 1, 'Balance of owner before');

    testing::set_caller_address(OWNER());
    state.erc1155.transferFrom(OWNER(), OWNER(), TOKEN_ID, TOKEN_VALUE);
    assert_event_update_balances(OWNER(), OWNER(), TOKEN_ID, TOKEN_VALUE);

    assert(state.erc1155.balance_of(OWNER(), TOKEN_ID) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_update_balances_from_approved() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_update_balances(owner, recipient, token_id, value);

    testing::set_caller_address(owner);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.transfer_from(owner, recipient, token_id, value);
    assert_event_update_balances(owner, recipient, token_id, value);

    assert_state_after_update_balances(owner, recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_update_balancesFrom_approved() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_update_balances(owner, recipient, token_id, value);

    testing::set_caller_address(owner);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.transferFrom(owner, recipient, token_id, value);
    assert_event_update_balances(owner, recipient, token_id, value);

    assert_state_after_update_balances(owner, recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_update_balances_from_approved_for_all() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_update_balances(owner, recipient, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.transfer_from(owner, recipient, token_id, value);
    assert_event_update_balances(owner, recipient, token_id, value);

    assert_state_after_update_balances(owner, recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_update_balancesFrom_approved_for_all() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_update_balances(owner, recipient, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.transferFrom(owner, recipient, token_id, value);
    assert_event_update_balances(owner, recipient, token_id, value);

    assert_state_after_update_balances(owner, recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: unauthorized caller',))]
fn test_update_balances_from_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.erc1155.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: unauthorized caller',))]
fn test_update_balancesFrom_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.erc1155.transferFrom(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE);
}

//
// safe_transfer_from & safeTransferFrom
//

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_account() {
    let mut state = setup();
    let account = setup_account();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    assert_state_before_update_balances(owner, account, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, account, token_id, value, DATA(true));
    assert_event_update_balances(owner, account, token_id, value);

    assert_state_after_update_balances(owner, account, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_account() {
    let mut state = setup();
    let account = setup_account();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    assert_state_before_update_balances(owner, account, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, account, token_id, value, DATA(true));
    assert_event_update_balances(owner, account, token_id, value);

    assert_state_after_update_balances(owner, account, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_account_camel() {
    let mut state = setup();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    assert_state_before_update_balances(owner, account, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, account, token_id, value, DATA(true));
    assert_event_update_balances(owner, account, token_id, value);

    assert_state_after_update_balances(owner, account, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_account_camel() {
    let mut state = setup();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    assert_state_before_update_balances(owner, account, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, account, token_id, value, DATA(true));
    assert_event_update_balances(owner, account, token_id, value);

    assert_state_after_update_balances(owner, account, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_receiver() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_receiver() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_receiver_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_receiver_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: safe transfer failed',))]
fn test_safe_transfer_from_to_receiver_failure() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: safe transfer failed',))]
fn test_safeTransferFrom_to_receiver_failure() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, receiver, token_id, value, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: safe transfer failed',))]
fn test_safe_transfer_from_to_receiver_failure_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: safe transfer failed',))]
fn test_safeTransferFrom_to_receiver_failure_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, receiver, token_id, value, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_safe_transfer_from_to_non_receiver() {
    let mut state = setup();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, recipient, token_id, value, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_safeTransferFrom_to_non_receiver() {
    let mut state = setup();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, recipient, token_id, value, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid token ID',))]
fn test_safe_transfer_from_nonexistent() {
    let mut state = STATE();
    state.erc1155.safe_transfer_from(ZERO(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid token ID',))]
fn test_safeTransferFrom_nonexistent() {
    let mut state = STATE();
    state.erc1155.safeTransferFrom(ZERO(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safe_transfer_from_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc1155.safe_transfer_from(OWNER(), ZERO(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safeTransferFrom_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc1155.safeTransferFrom(OWNER(), ZERO(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_owner() {
    let mut state = STATE();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = setup_receiver();
    state.erc1155.initializer(NAME, SYMBOL);
    state.erc1155._mint(owner, token_id, value);
    utils::drop_event(ZERO());

    assert(state.erc1155.balance_of(owner, token_id) == TOKEN_VALUE, 'Balance of owner before');

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, owner, token_id, value, DATA(true));
    assert_event_update_balances(owner, owner, token_id, value);

    assert(state.erc1155.balance_of(owner, token_id) == TOKEN_VALUE, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_owner() {
    let mut state = STATE();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = setup_receiver();
    state.erc1155.initializer(NAME, SYMBOL);
    state.erc1155._mint(owner, token_id, value);
    utils::drop_event(ZERO());

    assert(state.erc1155.balance_of(owner, token_id) == TOKEN_VALUE, 'Balance of owner before');

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, owner, token_id, value, DATA(true));
    assert_event_update_balances(owner, owner, token_id, value);

    assert(state.erc1155.balance_of(owner, token_id) == TOKEN_VALUE, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_owner_camel() {
    let mut state = STATE();
    let token_id = TOKEN_ID;
    let owner = setup_camel_receiver();
    let value = TOKEN_VALUE;
    state.erc1155.initializer(NAME, SYMBOL);
    state.erc1155._mint(owner, token_id, value);
    utils::drop_event(ZERO());

    assert(state.erc1155.balance_of(owner, token_id) == TOKEN_VALUE, 'Balance of owner before');

    testing::set_caller_address(owner);
    state.erc1155.safe_transfer_from(owner, owner, token_id, value, DATA(true));
    assert_event_update_balances(owner, owner, token_id, value);

    assert(state.erc1155.balance_of(owner, token_id) == TOKEN_VALUE, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_owner_camel() {
    let mut state = STATE();
    let token_id = TOKEN_ID;
    let owner = setup_camel_receiver();
    let value = TOKEN_VALUE;
    state.erc1155.initializer(NAME, SYMBOL);
    state.erc1155._mint(owner, token_id, value);
    utils::drop_event(ZERO());

    assert(state.erc1155.balance_of(owner, token_id) == TOKEN_VALUE, 'Balance of owner before');

    testing::set_caller_address(owner);
    state.erc1155.safeTransferFrom(owner, owner, token_id, value, DATA(true));
    assert_event_update_balances(owner, owner, token_id, value);

    assert(state.erc1155.balance_of(owner, token_id) == TOKEN_VALUE, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let value = TOKEN_VALUE;

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(OPERATOR());
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let value = TOKEN_VALUE;

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(OPERATOR());
    state.erc1155.safeTransferFrom(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let value = TOKEN_VALUE;

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155._mint(owner, token_id, value);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let value = TOKEN_VALUE;

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155._mint(owner, token_id, value);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_for_all() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let value = TOKEN_VALUE;

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_for_all() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let value = TOKEN_VALUE;

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_for_all_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let value = TOKEN_VALUE;

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_for_all_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let value = TOKEN_VALUE;

    assert_state_before_update_balances(owner, receiver, token_id, value);

    testing::set_caller_address(owner);
    state.erc1155.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.erc1155.safe_transfer_from(owner, receiver, token_id, value, DATA(true));
    assert_event_update_balances(owner, receiver, token_id, value);

    assert_state_after_update_balances(owner, receiver, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: unauthorized caller',))]
fn test_safe_transfer_from_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.erc1155.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: unauthorized caller',))]
fn test_safeTransferFrom_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.erc1155.safeTransferFrom(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

//
// _update_balances
//

#[test]
#[available_gas(20000000)]
fn test__update_balances() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_update_balances(owner, recipient, token_id, value);

    state.erc1155._update_balances(owner, recipient, token_id, value);
    assert_event_update_balances(owner, recipient, token_id, value);

    assert_state_after_update_balances(owner, recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid token ID',))]
fn test__update_balances_nonexistent() {
    let mut state = STATE();
    state.erc1155._update_balances(ZERO(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test__update_balances_to_zero() {
    let mut state = setup();
    state.erc1155._update_balances(OWNER(), ZERO(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: wrong sender',))]
fn test__update_balances_from_invalid_owner() {
    let mut state = setup();
    state.erc1155._update_balances(RECIPIENT(), OWNER(), TOKEN_ID, TOKEN_VALUE);
}

//
// _mint
//

#[test]
#[available_gas(20000000)]
fn test__mint() {
    let mut state = STATE();
    let recipient = RECIPIENT();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    assert_state_before_mint(recipient, token_id);
    state.erc1155._mint(recipient, TOKEN_ID, TOKEN_VALUE);
    assert_event_update_balances(ZERO(), recipient, token_id, value);

    assert_state_after_mint(recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test__mint_to_zero() {
    let mut state = STATE();
    state.erc1155._mint(ZERO(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: token already minted',))]
fn test__mint_already_exist() {
    let mut state = setup();
    state.erc1155._mint(RECIPIENT(), TOKEN_ID, TOKEN_VALUE);
}

//
// _safe_mint
//

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_receiver() {
    let mut state = STATE();
    let recipient = setup_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    assert_state_before_mint(recipient, token_id);
    state.erc1155._safe_mint(recipient, token_id, value, DATA(true));
    assert_event_update_balances(ZERO(), recipient, token_id, value);

    assert_state_after_mint(recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_receiver_camel() {
    let mut state = STATE();
    let recipient = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    assert_state_before_mint(recipient, token_id);
    state.erc1155._safe_mint(recipient, token_id, value, DATA(true));
    assert_event_update_balances(ZERO(), recipient, token_id, value);

    assert_state_after_mint(recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_account() {
    let mut state = STATE();
    let account = setup_account();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    assert_state_before_mint(account, token_id);
    state.erc1155._safe_mint(account, token_id, value, DATA(true));
    assert_event_update_balances(ZERO(), account, token_id, value);

    assert_state_after_mint(account, token_id, value);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_account_camel() {
    let mut state = STATE();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    assert_state_before_mint(account, token_id);
    state.erc1155._safe_mint(account, token_id, value, DATA(true));
    assert_event_update_balances(ZERO(), account, token_id, value);

    assert_state_after_mint(account, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test__safe_mint_to_non_receiver() {
    let mut state = STATE();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    assert_state_before_mint(recipient, token_id);
    state.erc1155._safe_mint(recipient, token_id, value, DATA(true));
    assert_state_after_mint(recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: safe mint failed',))]
fn test__safe_mint_to_receiver_failure() {
    let mut state = STATE();
    let recipient = setup_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    assert_state_before_mint(recipient, token_id);
    state.erc1155._safe_mint(recipient, token_id, value, DATA(false));
    assert_state_after_mint(recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: safe mint failed',))]
fn test__safe_mint_to_receiver_failure_camel() {
    let mut state = STATE();
    let recipient = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let value = TOKEN_VALUE;

    assert_state_before_mint(recipient, token_id);
    state.erc1155._safe_mint(recipient, token_id, value, DATA(false));
    assert_state_after_mint(recipient, token_id, value);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test__safe_mint_to_zero() {
    let mut state = STATE();
    state.erc1155._safe_mint(ZERO(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: token already minted',))]
fn test__safe_mint_already_exist() {
    let mut state = setup();
    state.erc1155._safe_mint(RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

//
// _burn
//

#[test]
#[available_gas(20000000)]
fn test__burn() {
    let mut state = setup();

    assert(state.erc1155.balance_of(OWNER(), TOKEN_ID) == TOKEN_VALUE, 'Balance of owner before');

    state.erc1155._burn(TOKEN_ID, TOKEN_VALUE);
    assert_event_update_balances(OWNER(), ZERO(), TOKEN_ID, TOKEN_VALUE);
    assert(state.erc1155.balance_of(OWNER(), TOKEN_ID) == 0, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid token ID',))]
fn test__burn_nonexistent() {
    let mut state = STATE();
    state.erc1155._burn(TOKEN_ID, TOKEN_VALUE);
}

//
// _set_uri
//

#[test]
#[available_gas(20000000)]
fn test__set_uri() {
    let mut state = setup();

    assert(state.erc1155.uri(TOKEN_ID) == 0, 'URI should be 0');
    state.erc1155._set_uri(TOKEN_ID, URI);
    assert(state.erc1155.uri(TOKEN_ID) == URI, 'URI should be set');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC1155: invalid token ID',))]
fn test__set_uri_nonexistent() {
    let mut state = STATE();
    state.erc1155._set_uri(TOKEN_ID, URI);
}

//
// Helpers
//

fn assert_state_before_update_balances(
    owner: ContractAddress, recipient: ContractAddress, token_id: u256, value: u256
) {
    let state = STATE();
    assert(state.erc1155.balance_of(owner, token_id) == value, 'Balance of owner before');
    assert(state.erc1155.balance_of(recipient, token_id) == 0, 'Balance of recipient before');
}

fn assert_state_after_update_balances(
    owner: ContractAddress, recipient: ContractAddress, token_id: u256, value: u256
) {
    let state = STATE();
    assert(state.erc1155.balance_of(owner, token_id) == 0, 'Balance of owner after');
    assert(state.erc1155.balance_of(recipient, token_id) == value, 'Balance of recipient after');
}

fn assert_state_before_mint(recipient: ContractAddress, token_id: u256) {
    let state = STATE();
    assert(state.erc1155.balance_of(recipient, token_id) == 0, 'Balance of recipient before');
}

fn assert_state_after_mint(recipient: ContractAddress, token_id: u256, value: u256) {
    let state = STATE();
    assert(state.erc1155.balance_of(recipient, token_id) == value, 'Balance of recipient after');
}

fn assert_event_approval_for_all(
    owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ApprovalForAll>(ZERO()).unwrap();
    assert(event.owner == owner, 'Invalid `owner`');
    assert(event.operator == operator, 'Invalid `operator`');
    assert(event.approved == approved, 'Invalid `approved`');
    utils::assert_no_events_left(ZERO());

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(operator);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_update_balances(
    from: ContractAddress, to: ContractAddress, token_id: u256, value: u256
) {
    let event = utils::pop_log::<Transfer>(ZERO()).unwrap();
    assert(event.from == from, 'Invalid `from`');
    assert(event.to == to, 'Invalid `to`');
    assert(event.token_id == token_id, 'Invalid `token_id`');
    assert(event.value == token_id, 'Invalid `token_id`');
    utils::assert_no_events_left(ZERO());

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    indexed_keys.append_serde(token_id);
    indexed_keys.append_serde(value);
    utils::assert_indexed_keys(event, indexed_keys.span());
}
