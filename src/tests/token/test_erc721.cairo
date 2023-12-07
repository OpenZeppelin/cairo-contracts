use integer::u256_from_felt252;
use openzeppelin::account::AccountComponent;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::introspection::src5;
use openzeppelin::introspection;
use openzeppelin::tests::mocks::account_mocks::{DualCaseAccountMock, CamelAccountMock};
use openzeppelin::tests::mocks::erc721_mocks::DualCaseERC721Mock;
use openzeppelin::tests::mocks::erc721_receiver_mocks::{
    CamelERC721ReceiverMock, SnakeERC721ReceiverMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{
    DATA, ZERO, OWNER, RECIPIENT, SPENDER, OPERATOR, OTHER, NAME, SYMBOL, URI, TOKEN_ID, PUBKEY,
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721Component::{
    ERC721CamelOnlyImpl, ERC721MetadataCamelOnlyImpl
};
use openzeppelin::token::erc721::ERC721Component::{Approval, ApprovalForAll, Transfer};
use openzeppelin::token::erc721::ERC721Component::{ERC721Impl, ERC721MetadataImpl, InternalImpl};
use openzeppelin::token::erc721::ERC721Component;
use openzeppelin::token::erc721;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::storage::StorageMapMemberAccessTrait;
use starknet::testing;

//
// Setup
//

type ComponentState = ERC721Component::ComponentState<DualCaseERC721Mock::ContractState>;

fn CONTRACT_STATE() -> DualCaseERC721Mock::ContractState {
    DualCaseERC721Mock::contract_state_for_testing()
}
fn COMPONENT_STATE() -> ComponentState {
    ERC721Component::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(NAME, SYMBOL);
    state._mint(OWNER(), TOKEN_ID);
    utils::drop_event(ZERO());
    state
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
// Initializers
//

#[test]
#[available_gas(20000000)]
fn test_initialize() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer(NAME, SYMBOL);

    assert(state.name() == NAME, 'Name should be NAME');
    assert(state.symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(state.balance_of(OWNER()) == 0, 'Balance should be zero');

    assert(mock_state.supports_interface(erc721::interface::IERC721_ID), 'Missing interface ID');
    assert(
        mock_state.supports_interface(erc721::interface::IERC721_METADATA_ID),
        'Missing interface ID'
    );
    assert(
        mock_state.supports_interface(introspection::interface::ISRC5_ID), 'Missing interface ID'
    );
}

//
// Getters
//

#[test]
#[available_gas(20000000)]
fn test_balance_of() {
    let state = setup();
    assert(state.balance_of(OWNER()) == 1, 'Should return balance');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid account',))]
fn test_balance_of_zero() {
    let state = setup();
    state.balance_of(ZERO());
}

#[test]
#[available_gas(20000000)]
fn test_owner_of() {
    let state = setup();
    assert(state.owner_of(TOKEN_ID) == OWNER(), 'Should return owner');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_owner_of_non_minted() {
    let state = setup();
    state.owner_of(u256_from_felt252(7));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_token_uri_non_minted() {
    let state = setup();
    state.token_uri(u256_from_felt252(7));
}

#[test]
#[available_gas(20000000)]
fn test_get_approved() {
    let mut state = setup();
    let spender = SPENDER();
    let token_id = TOKEN_ID;

    assert(state.get_approved(token_id) == ZERO(), 'Should return non-approval');
    state._approve(spender, token_id);
    assert(state.get_approved(token_id) == spender, 'Should return approval');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_get_approved_nonexistent() {
    let state = setup();
    state.get_approved(u256_from_felt252(7));
}

#[test]
#[available_gas(20000000)]
fn test__exists() {
    let mut state = COMPONENT_STATE();
    let zero = ZERO();
    let token_id = TOKEN_ID;

    assert(!state._exists(token_id), 'Token should not exist');
    let mut owner = state.ERC721_owners.read(token_id);
    assert(owner == zero, '');

    state._mint(RECIPIENT(), token_id);

    assert(state._exists(token_id), 'Token should exist');
    owner = state.ERC721_owners.read(token_id);
    assert(owner == RECIPIENT(), 'Invalid owner');

    state._burn(token_id);

    assert(!state._exists(token_id), 'Token should not exist');
    owner = state.ERC721_owners.read(token_id);
    assert(owner == zero, 'Invalid owner');
}

//
// approve & _approve
//

#[test]
#[available_gas(20000000)]
fn test_approve_from_owner() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID);
    assert_event_approval(OWNER(), SPENDER(), TOKEN_ID);

    assert(state.get_approved(TOKEN_ID) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(20000000)]
fn test_approve_from_operator() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    state.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.approve(SPENDER(), TOKEN_ID);
    assert_event_approval(OWNER(), SPENDER(), TOKEN_ID);

    assert(state.get_approved(TOKEN_ID) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn test_approve_from_unauthorized() {
    let mut state = setup();

    testing::set_caller_address(OTHER());
    state.approve(SPENDER(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: approval to owner',))]
fn test_approve_to_owner() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    state.approve(OWNER(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_approve_nonexistent() {
    let mut state = COMPONENT_STATE();
    state.approve(SPENDER(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
fn test__approve() {
    let mut state = setup();
    state._approve(SPENDER(), TOKEN_ID);
    assert_event_approval(OWNER(), SPENDER(), TOKEN_ID);

    assert(state.get_approved(TOKEN_ID) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: approval to owner',))]
fn test__approve_to_owner() {
    let mut state = setup();
    state._approve(OWNER(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test__approve_nonexistent() {
    let mut state = COMPONENT_STATE();
    state._approve(SPENDER(), TOKEN_ID);
}

//
// set_approval_for_all & _set_approval_for_all
//

#[test]
#[available_gas(20000000)]
fn test_set_approval_for_all() {
    let mut state = COMPONENT_STATE();
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
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval',))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(OWNER(), true);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval',))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(OWNER(), false);
}

#[test]
#[available_gas(20000000)]
fn test__set_approval_for_all() {
    let mut state = COMPONENT_STATE();
    assert(!state.is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    state._set_approval_for_all(OWNER(), OPERATOR(), true);
    assert_event_approval_for_all(OWNER(), OPERATOR(), true);

    assert(state.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');

    state._set_approval_for_all(OWNER(), OPERATOR(), false);
    assert_event_approval_for_all(OWNER(), OPERATOR(), false);

    assert(!state.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval',))]
fn test__set_approval_for_all_owner_equal_operator_true() {
    let mut state = COMPONENT_STATE();
    state._set_approval_for_all(OWNER(), OWNER(), true);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval',))]
fn test__set_approval_for_all_owner_equal_operator_false() {
    let mut state = COMPONENT_STATE();
    state._set_approval_for_all(OWNER(), OWNER(), false);
}

//
// transfer_from & transferFrom
//

#[test]
#[available_gas(20000000)]
fn test_transfer_from_owner() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();
    // set approval to check reset
    state._approve(OTHER(), token_id);
    utils::drop_event(ZERO());

    assert_state_before_transfer(owner, recipient, token_id);
    assert(state.get_approved(token_id) == OTHER(), 'Approval not implicitly reset');

    testing::set_caller_address(owner);
    state.transfer_from(owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_owner() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();
    // set approval to check reset
    state._approve(OTHER(), token_id);
    utils::drop_event(ZERO());

    assert_state_before_transfer(owner, recipient, token_id);
    assert(state.get_approved(token_id) == OTHER(), 'Approval not implicitly reset');

    testing::set_caller_address(owner);
    state.transferFrom(owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_transfer_from_nonexistent() {
    let mut state = COMPONENT_STATE();
    state.transfer_from(ZERO(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_transferFrom_nonexistent() {
    let mut state = COMPONENT_STATE();
    state.transferFrom(ZERO(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test_transfer_from_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transfer_from(OWNER(), ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test_transferFrom_to_zero() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    state.transferFrom(OWNER(), ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_to_owner() {
    let mut state = setup();

    assert(state.owner_of(TOKEN_ID) == OWNER(), 'Ownership before');
    assert(state.balance_of(OWNER()) == 1, 'Balance of owner before');

    testing::set_caller_address(OWNER());
    state.transfer_from(OWNER(), OWNER(), TOKEN_ID);
    assert_event_transfer(OWNER(), OWNER(), TOKEN_ID);

    assert(state.owner_of(TOKEN_ID) == OWNER(), 'Ownership after');
    assert(state.balance_of(OWNER()) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_to_owner() {
    let mut state = setup();

    assert(state.owner_of(TOKEN_ID) == OWNER(), 'Ownership before');
    assert(state.balance_of(OWNER()) == 1, 'Balance of owner before');

    testing::set_caller_address(OWNER());
    state.transferFrom(OWNER(), OWNER(), TOKEN_ID);
    assert_event_transfer(OWNER(), OWNER(), TOKEN_ID);

    assert(state.owner_of(TOKEN_ID) == OWNER(), 'Ownership after');
    assert(state.balance_of(OWNER()) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_approved() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(owner, recipient, token_id);

    testing::set_caller_address(owner);
    state.approve(OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.transfer_from(owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_approved() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(owner, recipient, token_id);

    testing::set_caller_address(owner);
    state.approve(OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.transferFrom(owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_approved_for_all() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(owner, recipient, token_id);

    testing::set_caller_address(owner);
    state.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.transfer_from(owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_approved_for_all() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(owner, recipient, token_id);

    testing::set_caller_address(owner);
    state.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.transferFrom(owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn test_transfer_from_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn test_transferFrom_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.transferFrom(OWNER(), RECIPIENT(), TOKEN_ID);
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
    let owner = OWNER();

    assert_state_before_transfer(owner, account, token_id);

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, account, token_id, DATA(true));
    assert_event_transfer(owner, account, token_id);

    assert_state_after_transfer(owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_account() {
    let mut state = setup();
    let account = setup_account();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, account, token_id);

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, account, token_id, DATA(true));
    assert_event_transfer(owner, account, token_id);

    assert_state_after_transfer(owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_account_camel() {
    let mut state = setup();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, account, token_id);

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, account, token_id, DATA(true));
    assert_event_transfer(owner, account, token_id);

    assert_state_after_transfer(owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_account_camel() {
    let mut state = setup();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, account, token_id);

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, account, token_id, DATA(true));
    assert_event_transfer(owner, account, token_id);

    assert_state_after_transfer(owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_receiver() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_receiver() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_receiver_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_receiver_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed',))]
fn test_safe_transfer_from_to_receiver_failure() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed',))]
fn test_safeTransferFrom_to_receiver_failure() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed',))]
fn test_safe_transfer_from_to_receiver_failure_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed',))]
fn test_safeTransferFrom_to_receiver_failure_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_safe_transfer_from_to_non_receiver() {
    let mut state = setup();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, recipient, token_id, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_safeTransferFrom_to_non_receiver() {
    let mut state = setup();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, recipient, token_id, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_safe_transfer_from_nonexistent() {
    let mut state = COMPONENT_STATE();
    state.safe_transfer_from(ZERO(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_safeTransferFrom_nonexistent() {
    let mut state = COMPONENT_STATE();
    state.safeTransferFrom(ZERO(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test_safe_transfer_from_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.safe_transfer_from(OWNER(), ZERO(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test_safeTransferFrom_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.safeTransferFrom(OWNER(), ZERO(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_owner() {
    let mut state = COMPONENT_STATE();
    let token_id = TOKEN_ID;
    let owner = setup_receiver();
    state.initializer(NAME, SYMBOL);
    state._mint(owner, token_id);
    utils::drop_event(ZERO());

    assert(state.owner_of(token_id) == owner, 'Ownership before');
    assert(state.balance_of(owner) == 1, 'Balance of owner before');

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, owner, token_id, DATA(true));
    assert_event_transfer(owner, owner, token_id);

    assert(state.owner_of(token_id) == owner, 'Ownership after');
    assert(state.balance_of(owner) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_owner() {
    let mut state = COMPONENT_STATE();
    let token_id = TOKEN_ID;
    let owner = setup_receiver();
    state.initializer(NAME, SYMBOL);
    state._mint(owner, token_id);
    utils::drop_event(ZERO());

    assert(state.owner_of(token_id) == owner, 'Ownership before');
    assert(state.balance_of(owner) == 1, 'Balance of owner before');

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, owner, token_id, DATA(true));
    assert_event_transfer(owner, owner, token_id);

    assert(state.owner_of(token_id) == owner, 'Ownership after');
    assert(state.balance_of(owner) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_owner_camel() {
    let mut state = COMPONENT_STATE();
    let token_id = TOKEN_ID;
    let owner = setup_camel_receiver();
    state.initializer(NAME, SYMBOL);
    state._mint(owner, token_id);
    utils::drop_event(ZERO());

    assert(state.owner_of(token_id) == owner, 'Ownership before');
    assert(state.balance_of(owner) == 1, 'Balance of owner before');

    testing::set_caller_address(owner);
    state.safe_transfer_from(owner, owner, token_id, DATA(true));
    assert_event_transfer(owner, owner, token_id);

    assert(state.owner_of(token_id) == owner, 'Ownership after');
    assert(state.balance_of(owner) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_owner_camel() {
    let mut state = COMPONENT_STATE();
    let token_id = TOKEN_ID;
    let owner = setup_camel_receiver();
    state.initializer(NAME, SYMBOL);
    state._mint(owner, token_id);
    utils::drop_event(ZERO());

    assert(state.owner_of(token_id) == owner, 'Ownership before');
    assert(state.balance_of(owner) == 1, 'Balance of owner before');

    testing::set_caller_address(owner);
    state.safeTransferFrom(owner, owner, token_id, DATA(true));
    assert_event_transfer(owner, owner, token_id);

    assert(state.owner_of(token_id) == owner, 'Ownership after');
    assert(state.balance_of(owner) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.approve(OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.approve(OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.approve(OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.approve(OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_for_all() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_for_all() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_for_all_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_for_all_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    state.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    state.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn test_safe_transfer_from_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn test_safeTransferFrom_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.safeTransferFrom(OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

//
// _transfer
//

#[test]
#[available_gas(20000000)]
fn test__transfer() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(owner, recipient, token_id);

    state._transfer(owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test__transfer_nonexistent() {
    let mut state = COMPONENT_STATE();
    state._transfer(ZERO(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test__transfer_to_zero() {
    let mut state = setup();
    state._transfer(OWNER(), ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: wrong sender',))]
fn test__transfer_from_invalid_owner() {
    let mut state = setup();
    state._transfer(RECIPIENT(), OWNER(), TOKEN_ID);
}

//
// _mint
//

#[test]
#[available_gas(20000000)]
fn test__mint() {
    let mut state = COMPONENT_STATE();
    let recipient = RECIPIENT();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    state._mint(recipient, TOKEN_ID);
    assert_event_transfer(ZERO(), recipient, token_id);

    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test__mint_to_zero() {
    let mut state = COMPONENT_STATE();
    state._mint(ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: token already minted',))]
fn test__mint_already_exist() {
    let mut state = setup();
    state._mint(RECIPIENT(), TOKEN_ID);
}

//
// _safe_mint
//

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_receiver() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_receiver();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    state._safe_mint(recipient, token_id, DATA(true));
    assert_event_transfer(ZERO(), recipient, token_id);

    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_receiver_camel() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_camel_receiver();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    state._safe_mint(recipient, token_id, DATA(true));
    assert_event_transfer(ZERO(), recipient, token_id);

    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_account() {
    let mut state = COMPONENT_STATE();
    let account = setup_account();
    let token_id = TOKEN_ID;

    assert_state_before_mint(account);
    state._safe_mint(account, token_id, DATA(true));
    assert_event_transfer(ZERO(), account, token_id);

    assert_state_after_mint(account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_account_camel() {
    let mut state = COMPONENT_STATE();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;

    assert_state_before_mint(account);
    state._safe_mint(account, token_id, DATA(true));
    assert_event_transfer(ZERO(), account, token_id);

    assert_state_after_mint(account, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test__safe_mint_to_non_receiver() {
    let mut state = COMPONENT_STATE();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    state._safe_mint(recipient, token_id, DATA(true));
    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe mint failed',))]
fn test__safe_mint_to_receiver_failure() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_receiver();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    state._safe_mint(recipient, token_id, DATA(false));
    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe mint failed',))]
fn test__safe_mint_to_receiver_failure_camel() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_camel_receiver();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    state._safe_mint(recipient, token_id, DATA(false));
    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver',))]
fn test__safe_mint_to_zero() {
    let mut state = COMPONENT_STATE();
    state._safe_mint(ZERO(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: token already minted',))]
fn test__safe_mint_already_exist() {
    let mut state = setup();
    state._safe_mint(RECIPIENT(), TOKEN_ID, DATA(true));
}

//
// _burn
//

#[test]
#[available_gas(20000000)]
fn test__burn() {
    let mut state = setup();

    state._approve(OTHER(), TOKEN_ID);
    utils::drop_event(ZERO());

    assert(state.owner_of(TOKEN_ID) == OWNER(), 'Ownership before');
    assert(state.balance_of(OWNER()) == 1, 'Balance of owner before');
    assert(state.get_approved(TOKEN_ID) == OTHER(), 'Approval before');

    state._burn(TOKEN_ID);
    assert_event_transfer(OWNER(), ZERO(), TOKEN_ID);

    assert(state.ERC721_owners.read(TOKEN_ID) == ZERO(), 'Ownership after');
    assert(state.balance_of(OWNER()) == 0, 'Balance of owner after');
    assert(state.ERC721_token_approvals.read(TOKEN_ID) == ZERO(), 'Approval after');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test__burn_nonexistent() {
    let mut state = COMPONENT_STATE();
    state._burn(TOKEN_ID);
}

//
// _set_token_uri
//

#[test]
#[available_gas(20000000)]
fn test__set_token_uri() {
    let mut state = setup();

    assert(state.token_uri(TOKEN_ID) == 0, 'URI should be 0');
    state._set_token_uri(TOKEN_ID, URI);
    assert(state.token_uri(TOKEN_ID) == URI, 'URI should be set');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test__set_token_uri_nonexistent() {
    let mut state = COMPONENT_STATE();
    state._set_token_uri(TOKEN_ID, URI);
}

//
// Helpers
//

fn assert_state_before_transfer(
    owner: ContractAddress, recipient: ContractAddress, token_id: u256
) {
    let state = COMPONENT_STATE();
    assert(state.owner_of(token_id) == owner, 'Ownership before');
    assert(state.balance_of(owner) == 1, 'Balance of owner before');
    assert(state.balance_of(recipient) == 0, 'Balance of recipient before');
}

fn assert_state_after_transfer(owner: ContractAddress, recipient: ContractAddress, token_id: u256) {
    let state = COMPONENT_STATE();
    assert(state.owner_of(token_id) == recipient, 'Ownership after');
    assert(state.balance_of(owner) == 0, 'Balance of owner after');
    assert(state.balance_of(recipient) == 1, 'Balance of recipient after');
    assert(state.get_approved(token_id) == ZERO(), 'Approval not implicitly reset');
}

fn assert_state_before_mint(recipient: ContractAddress) {
    let state = COMPONENT_STATE();
    assert(state.balance_of(recipient) == 0, 'Balance of recipient before');
}

fn assert_state_after_mint(recipient: ContractAddress, token_id: u256) {
    let state = COMPONENT_STATE();
    assert(state.owner_of(token_id) == recipient, 'Ownership after');
    assert(state.balance_of(recipient) == 1, 'Balance of recipient after');
    assert(state.get_approved(token_id) == ZERO(), 'Approval implicitly set');
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

fn assert_event_approval(owner: ContractAddress, approved: ContractAddress, token_id: u256) {
    let event = utils::pop_log::<Approval>(ZERO()).unwrap();
    assert(event.owner == owner, 'Invalid `owner`');
    assert(event.approved == approved, 'Invalid `approved`');
    assert(event.token_id == token_id, 'Invalid `token_id`');
    utils::assert_no_events_left(ZERO());

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(approved);
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_transfer(from: ContractAddress, to: ContractAddress, token_id: u256) {
    let event = utils::pop_log::<Transfer>(ZERO()).unwrap();
    assert(event.from == from, 'Invalid `from`');
    assert(event.to == to, 'Invalid `to`');
    assert(event.token_id == token_id, 'Invalid `token_id`');
    utils::assert_no_events_left(ZERO());

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}
