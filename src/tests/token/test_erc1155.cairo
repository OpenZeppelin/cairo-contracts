use core::starknet::storage::StorageMemberAccessTrait;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::introspection::src5;
use openzeppelin::introspection;
use openzeppelin::tests::mocks::account_mocks::{SnakeAccountMock, CamelAccountMock};
use openzeppelin::tests::mocks::erc1155_mocks::DualCaseERC1155Mock;
use openzeppelin::tests::mocks::erc1155_receiver_mocks::{
    CamelERC1155ReceiverMock, SnakeERC1155ReceiverMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::mocks::src5_mocks::DualCaseSRC5Mock;
use openzeppelin::tests::utils::constants::{
    DATA, ZERO, OWNER, RECIPIENT, OPERATOR, OTHER, TOKEN_ID, TOKEN_VALUE, PUBKEY,
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
    state.mint_with_acceptance_check(owner, TOKEN_ID + 100, TOKEN_VALUE, array![].span());
    utils::drop_events(ZERO(), 2);
    (state, owner)
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(SnakeERC1155ReceiverMock::TEST_CLASS_HASH, array![])
}

fn setup_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(SnakeAccountMock::TEST_CLASS_HASH, calldata)
}

fn setup_account_with_salt(salt: felt252) -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy_with_salt(SnakeAccountMock::TEST_CLASS_HASH, calldata, salt)
}

fn setup_src5() -> ContractAddress {
    utils::deploy(DualCaseSRC5Mock::TEST_CLASS_HASH, array![])
}

//
// Initializers
//

#[test]
fn test_initialize() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer("URI");

    assert_eq!(state.ERC1155_uri.read(), "URI");
    assert!(state.balance_of(OWNER(), TOKEN_ID).is_zero());

    let supports_ierc1155 = mock_state.supports_interface(erc1155::interface::IERC1155_ID);
    assert!(supports_ierc1155);

    let supports_ierc1155_metadata_uri = mock_state
        .supports_interface(erc1155::interface::IERC1155_METADATA_URI_ID);
    assert!(supports_ierc1155_metadata_uri);

    let supports_isrc5 = mock_state.supports_interface(introspection::interface::ISRC5_ID);
    assert!(supports_isrc5);
}

//
// balance_of & balanceOf
//

#[test]
fn test_balance_of() {
    let (state, owner) = setup();
    let balance = state.balance_of(owner, TOKEN_ID);
    assert_eq!(balance, TOKEN_VALUE);
}

#[test]
fn test_balanceOf() {
    let (state, owner) = setup();
    let balance = state.balanceOf(owner, TOKEN_ID);
    assert_eq!(balance, TOKEN_VALUE);
}

//
// balance_of_batch & balanceOfBatch
//

#[test]
fn test_balance_of_batch() {
    let (state, owner) = setup();
    let accounts = array![owner, OTHER()].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID].span();

    let balances = state.balance_of_batch(accounts, token_ids);
    assert_eq!(*balances.at(0), TOKEN_VALUE);
    assert!((*balances.at(1)).is_zero());
}

#[test]
fn test_balanceOfBatch() {
    let (state, owner) = setup();
    let accounts = array![owner, OTHER()].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID].span();

    let balances = state.balanceOfBatch(accounts, token_ids);
    assert_eq!(*balances.at(0), TOKEN_VALUE);
    assert!((*balances.at(1)).is_zero());
}

#[test]
#[should_panic(expected: ('ERC1155: no equal array length',))]
fn test_balance_of_batch_invalid_inputs() {
    let (state, owner) = setup();
    let accounts = array![owner, OTHER()].span();
    let token_ids = array![TOKEN_ID].span();

    state.balance_of_batch(accounts, token_ids);
}

#[test]
#[should_panic(expected: ('ERC1155: no equal array length',))]
fn test_balanceOfBatch_invalid_inputs() {
    let (state, owner) = setup();
    let accounts = array![owner, OTHER()].span();
    let token_ids = array![TOKEN_ID].span();

    state.balanceOfBatch(accounts, token_ids);
}

//
// safe_transfer_from & safeTransferFrom
//

#[test]
fn test_safe_transfer_from_owner_to_receiver() {
    let (mut state, owner) = setup();
    let recipient = setup_receiver();
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    state.safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE, data);
    assert_only_event_transfer_single(owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
fn test_safeTransferFrom_owner_to_receiver() {
    let (mut state, owner) = setup();
    let recipient = setup_receiver();
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    state.safeTransferFrom(owner, recipient, TOKEN_ID, TOKEN_VALUE, data);
    assert_only_event_transfer_single(owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
fn test_safe_transfer_from_owner_to_account() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    state.safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE, data);
    assert_only_event_transfer_single(owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
fn test_safeTransferFrom_owner_to_account() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    state.safeTransferFrom(owner, recipient, TOKEN_ID, TOKEN_VALUE, data);
    assert_only_event_transfer_single(owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
fn test_safe_transfer_from_approved_operator() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let operator = OPERATOR();
    let data = array![].span();

    testing::set_caller_address(owner);
    state.set_approval_for_all(operator, true);
    assert_only_event_approval_for_all(owner, operator, true);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    testing::set_caller_address(operator);
    state.safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE, data);
    assert_only_event_transfer_single(operator, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
fn test_safeTransferFrom_approved_operator() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let operator = OPERATOR();
    let data = array![].span();

    testing::set_caller_address(owner);
    state.set_approval_for_all(operator, true);
    assert_only_event_approval_for_all(owner, operator, true);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    testing::set_caller_address(operator);
    state.safeTransferFrom(owner, recipient, TOKEN_ID, TOKEN_VALUE, data);
    assert_only_event_transfer_single(operator, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender',))]
fn test_safe_transfer_from_from_zero() {
    let (mut state, owner) = setup();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.safe_transfer_from(ZERO(), owner, TOKEN_ID, TOKEN_VALUE, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender',))]
fn test_safeTransferFrom_from_zero() {
    let (mut state, owner) = setup();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.safeTransferFrom(ZERO(), owner, TOKEN_ID, TOKEN_VALUE, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safe_transfer_from_to_zero() {
    let (mut state, owner) = setup();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.safe_transfer_from(owner, ZERO(), TOKEN_ID, TOKEN_VALUE, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safeTransferFrom_to_zero() {
    let (mut state, owner) = setup();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.safeTransferFrom(owner, ZERO(), TOKEN_ID, TOKEN_VALUE, data);
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized operator',))]
fn test_safe_transfer_from_unauthorized() {
    let (mut state, owner) = setup();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.safe_transfer_from(OTHER(), owner, TOKEN_ID, TOKEN_VALUE, data);
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized operator',))]
fn test_safeTransferFrom_unauthorized() {
    let (mut state, owner) = setup();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.safeTransferFrom(OTHER(), owner, TOKEN_ID, TOKEN_VALUE, data);
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance',))]
fn test_safe_transfer_from_insufficient_balance() {
    let (mut state, owner) = setup();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.safe_transfer_from(owner, OTHER(), TOKEN_ID, TOKEN_VALUE + 1, data);
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance',))]
fn test_safeTransferFrom_insufficient_balance() {
    let (mut state, owner) = setup();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.safeTransferFrom(owner, OTHER(), TOKEN_ID, TOKEN_VALUE + 1, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safe_transfer_from_non_account_non_receiver() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let non_receiver = setup_src5();
    testing::set_caller_address(owner);

    state.safe_transfer_from(owner, non_receiver, TOKEN_ID, TOKEN_VALUE, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safeTransferFrom_non_account_non_receiver() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let non_receiver = setup_src5();
    testing::set_caller_address(owner);

    state.safeTransferFrom(owner, non_receiver, TOKEN_ID, TOKEN_VALUE, data);
}

//
// safe_batch_transfer_from & safeBatchTransferFrom
//

#[test]
fn test_safe_batch_transfer_from_owner_to_receiver() {
    let (mut state, owner) = setup();
    let recipient = setup_receiver();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    state.safe_batch_transfer_from(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}

#[test]
fn test_safeBatchTransferFrom_ownerto_receiver() {
    let (mut state, owner) = setup();
    let recipient = setup_receiver();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    state.safeBatchTransferFrom(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}

#[test]
fn test_safe_batch_transfer_from_owner_to_account() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    state.safe_batch_transfer_from(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}

#[test]
fn test_safeBatchTransferFrom_owner_to_account() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    state.safeBatchTransferFrom(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}


#[test]
fn test_safe_batch_transfer_from_approved_operator() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let operator = OPERATOR();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();

    testing::set_caller_address(owner);
    state.set_approval_for_all(operator, true);
    assert_only_event_approval_for_all(owner, operator, true);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    testing::set_caller_address(operator);
    state.safe_batch_transfer_from(owner, recipient, token_ids, values, data);
    // assert_only_event_transfer_batch(operator, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}

#[test]
fn test_safeBatchTransferFrom_approved_operator() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let operator = OPERATOR();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();

    testing::set_caller_address(owner);
    state.set_approval_for_all(operator, true);
    assert_only_event_approval_for_all(owner, operator, true);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    testing::set_caller_address(operator);
    state.safeBatchTransferFrom(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(operator, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender',))]
fn test_safe_batch_transfer_from_from_zero() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    state.safe_batch_transfer_from(ZERO(), owner, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender',))]
fn test_safeBatchTransferFrom_from_zero() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    state.safeBatchTransferFrom(ZERO(), owner, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safe_batch_transfer_from_to_zero() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    state.safe_batch_transfer_from(owner, ZERO(), token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safeBatchTransferFrom_to_zero() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    state.safeBatchTransferFrom(owner, ZERO(), token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized operator',))]
fn test_safe_batch_transfer_from_unauthorized() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    state.safe_batch_transfer_from(OTHER(), owner, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized operator',))]
fn test_safeBatchTransferFrom_unauthorized() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    state.safeBatchTransferFrom(OTHER(), owner, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance',))]
fn test_safe_batch_transfer_from_insufficient_balance() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID + 100].span();
    let values = array![TOKEN_VALUE + 1, TOKEN_VALUE].span();
    testing::set_caller_address(owner);

    state.safe_batch_transfer_from(owner, OTHER(), token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance',))]
fn test_safeBatchTransferFrom_insufficient_balance() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID + 100].span();
    let values = array![TOKEN_VALUE + 1, TOKEN_VALUE].span();
    testing::set_caller_address(owner);

    state.safeBatchTransferFrom(owner, OTHER(), token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safe_batch_transfer_from_non_account_non_receiver() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_split_values(5);
    let non_receiver = setup_src5();
    testing::set_caller_address(owner);

    state.safe_batch_transfer_from(owner, non_receiver, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_safeBatchTransferFrom_non_account_non_receiver() {
    let (mut state, owner) = setup();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_split_values(5);
    let non_receiver = setup_src5();
    testing::set_caller_address(owner);

    state.safeBatchTransferFrom(owner, non_receiver, token_ids, values, data);
}

//
// set_approval_for_all & is_approved_for_all
//

#[test]
fn test_set_approval_for_all_and_is_approved_for_all() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());

    let not_approved_for_all = !state.is_approved_for_all(OWNER(), OPERATOR());
    assert!(not_approved_for_all);

    state.set_approval_for_all(OPERATOR(), true);
    assert_only_event_approval_for_all(OWNER(), OPERATOR(), true);

    let is_approved_for_all = state.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);

    state.set_approval_for_all(OPERATOR(), false);
    assert_only_event_approval_for_all(OWNER(), OPERATOR(), false);

    let not_approved_for_all = !state.is_approved_for_all(OWNER(), OPERATOR());
    assert!(not_approved_for_all);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(OWNER(), true);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(OWNER(), false);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid operator',))]
fn test_set_approval_for_all_to_zero_true() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(ZERO(), true);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid operator',))]
fn test_set_approval_for_all_to_zero_false() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(ZERO(), false);
}


//
// setApprovalForAll & isApprovedForAll
//

#[test]
fn test_setApprovalForAll_and_isApprovedForAll() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());

    let not_approved_for_all = !state.isApprovedForAll(OWNER(), OPERATOR());
    assert!(not_approved_for_all);

    state.setApprovalForAll(OPERATOR(), true);
    assert_only_event_approval_for_all(OWNER(), OPERATOR(), true);

    let is_approved_for_all = state.isApprovedForAll(OWNER(), OPERATOR());
    assert!(is_approved_for_all);

    state.setApprovalForAll(OPERATOR(), false);
    assert_only_event_approval_for_all(OWNER(), OPERATOR(), false);

    let not_approved_for_all = !state.isApprovedForAll(OWNER(), OPERATOR());
    assert!(not_approved_for_all);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test_setApprovalForAll_owner_equal_operator_true() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.set_approval_for_all(OWNER(), true);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval',))]
fn test_setApprovalForAll_owner_equal_operator_false() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.setApprovalForAll(OWNER(), false);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid operator',))]
fn test_setApprovalForAll_to_zero_true() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.setApprovalForAll(ZERO(), true);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid operator',))]
fn test_setApprovalForAll_to_zero_false() {
    let mut state = COMPONENT_STATE();
    testing::set_caller_address(OWNER());
    state.setApprovalForAll(ZERO(), false);
}

//
// update
//

#[test]
fn test_update_single_from_non_zero_to_non_zero() {
    let (mut state, owner) = setup();
    let recipient = RECIPIENT();
    let token_ids = array![TOKEN_ID].span();
    let values = array![TOKEN_VALUE].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    state.update(owner, recipient, token_ids, values);
    assert_only_event_transfer_single(owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
fn test_update_batch_from_non_zero_to_non_zero() {
    let (mut state, owner) = setup();
    let recipient = RECIPIENT();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    state.update(owner, recipient, token_ids, values);
    assert_only_event_transfer_batch(owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}

#[test]
fn test_update_from_non_zero_to_zero() {
    let (mut state, owner) = setup();
    let recipient = ZERO();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    state.update(owner, recipient, token_ids, values);
    assert_only_event_transfer_batch(owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_to_zero_batch(owner, recipient, token_ids);
}

#[test]
fn test_update_from_zero_to_non_zero() {
    let (mut state, owner) = setup();
    let recipient = RECIPIENT();
    let sender = ZERO();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    assert_state_before_transfer_from_zero_batch(sender, recipient, token_ids);

    state.update(sender, recipient, token_ids, values);
    assert_only_event_transfer_batch(owner, sender, recipient, token_ids, values);

    assert_state_after_transfer_from_zero_batch(sender, recipient, token_ids);
}

#[test]
#[should_panic(expected: ('ERC1155: no equal array length',))]
fn test_update_invalid_inputs() {
    let (mut state, owner) = setup();
    let recipient = RECIPIENT();
    let token_ids = array![TOKEN_ID].span();
    let values = array![TOKEN_VALUE, TOKEN_VALUE].span();

    state.update(owner, recipient, token_ids, values);
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance',))]
fn test_update_insufficient_balance() {
    let (mut state, owner) = setup();
    let recipient = RECIPIENT();
    let token_ids = array![TOKEN_ID].span();
    let values = array![TOKEN_VALUE + 1].span();

    state.update(owner, recipient, token_ids, values);
}


//
// update_with_acceptance_check
//

#[test]
fn test_update_wac_single_from_non_zero_to_non_zero() {
    let (mut state, owner) = setup();
    let recipient = setup_receiver();
    let token_ids = array![TOKEN_ID].span();
    let values = array![TOKEN_VALUE].span();
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_single(owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
fn test_update_wac_single_from_non_zero_to_non_zero_account() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let token_ids = array![TOKEN_ID].span();
    let values = array![TOKEN_VALUE].span();
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_single(owner, recipient, TOKEN_ID);

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_single(owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(owner, recipient, TOKEN_ID);
}

#[test]
fn test_update_wac_batch_from_non_zero_to_non_zero() {
    let (mut state, owner) = setup();
    let recipient = setup_receiver();
    let (token_ids, values) = get_ids_and_values();
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}

#[test]
fn test_update_wac_batch_from_non_zero_to_non_zero_account() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let (token_ids, values) = get_ids_and_values();
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_batch(owner, recipient, token_ids);

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(owner, recipient, token_ids);
}

#[test]
#[should_panic(expected: ('CONTRACT_NOT_DEPLOYED',))]
fn test_update_wac_from_non_zero_to_zero() {
    let (mut state, owner) = setup();
    let recipient = ZERO();
    let (token_ids, values) = get_ids_and_values();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
}

#[test]
fn test_update_wac_from_zero_to_non_zero() {
    let (mut state, owner) = setup();
    let recipient = setup_receiver();
    let sender = ZERO();
    let (token_ids, values) = get_ids_and_values();
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_from_zero_batch(sender, recipient, token_ids);

    state.update_with_acceptance_check(sender, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(owner, sender, recipient, token_ids, values);

    assert_state_after_transfer_from_zero_batch(sender, recipient, token_ids);
}

#[test]
fn test_update_wac_from_zero_to_non_zero_account() {
    let (mut state, owner) = setup();
    let recipient = setup_account_with_salt(1);
    let sender = ZERO();
    let (token_ids, values) = get_ids_and_values();
    let data = array![].span();
    testing::set_caller_address(owner);

    assert_state_before_transfer_from_zero_batch(sender, recipient, token_ids);

    state.update_with_acceptance_check(sender, recipient, token_ids, values, data);
    assert_only_event_transfer_batch(owner, sender, recipient, token_ids, values);

    assert_state_after_transfer_from_zero_batch(sender, recipient, token_ids);
}

#[test]
#[should_panic(expected: ('ERC1155: no equal array length',))]
fn test_update_wac_invalid_inputs() {
    let (mut state, owner) = setup();
    let recipient = RECIPIENT();
    let token_ids = array![TOKEN_ID].span();
    let values = array![TOKEN_VALUE, TOKEN_VALUE].span();
    let data = array![].span();

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance',))]
fn test_update_wac_insufficient_balance() {
    let (mut state, owner) = setup();
    let recipient = RECIPIENT();
    let token_ids = array![TOKEN_ID].span();
    let values = array![TOKEN_VALUE + 1].span();
    let data = array![].span();

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_update_wac_single_to_non_receiver() {
    let (mut state, owner) = setup();
    let recipient = setup_src5();
    let token_ids = array![TOKEN_ID].span();
    let values = array![TOKEN_VALUE].span();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_update_wac_batch_to_non_receiver() {
    let (mut state, owner) = setup();
    let recipient = setup_src5();
    let (token_ids, values) = get_ids_and_values();
    let data = array![].span();
    testing::set_caller_address(owner);

    state.update_with_acceptance_check(owner, recipient, token_ids, values, data);
}

//
// mint_with_acceptance_check
//

#[test]
fn test_mint_wac_to_receiver() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_receiver();
    let data = array![].span();
    testing::set_caller_address(OTHER());

    let balance_of_recipient = state.balance_of(recipient, TOKEN_ID);
    assert!(balance_of_recipient.is_zero());

    state.mint_with_acceptance_check(recipient, TOKEN_ID, TOKEN_VALUE, data);
    assert_only_event_transfer_single(OTHER(), ZERO(), recipient, TOKEN_ID, TOKEN_VALUE);

    let balance_of_recipient = state.balance_of(recipient, TOKEN_ID);
    assert_eq!(balance_of_recipient, TOKEN_VALUE);
}

#[test]
fn test_mint_wac_to_account() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_account_with_salt(1);
    let data = array![].span();
    testing::set_caller_address(OTHER());

    let balance_of_recipient = state.balance_of(recipient, TOKEN_ID);
    assert!(balance_of_recipient.is_zero());

    state.mint_with_acceptance_check(recipient, TOKEN_ID, TOKEN_VALUE, data);
    assert_only_event_transfer_single(OTHER(), ZERO(), recipient, TOKEN_ID, TOKEN_VALUE);

    let balance_of_recipient = state.balance_of(recipient, TOKEN_ID);
    assert_eq!(balance_of_recipient, TOKEN_VALUE);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_mint_wac_to_zero() {
    let mut state = COMPONENT_STATE();
    let recipient = ZERO();
    let data = array![].span();

    state.mint_with_acceptance_check(recipient, TOKEN_ID, TOKEN_VALUE, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_mint_wac_to_non_receiver() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_src5();
    let data = array![].span();

    state.mint_with_acceptance_check(recipient, TOKEN_ID, TOKEN_VALUE, data);
}

//
// batch_mint_with_acceptance_check
//

#[test]
fn test_batch_mint_wac_to_receiver() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_receiver();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(OTHER());

    let balance_of_recipient_token_1_before = state.balance_of(recipient, TOKEN_ID);
    assert!(balance_of_recipient_token_1_before.is_zero());
    let balance_of_recipient_token_2_before = state.balance_of(recipient, TOKEN_ID + 100);
    assert!(balance_of_recipient_token_2_before.is_zero());

    state.batch_mint_with_acceptance_check(recipient, token_ids, values, data);
    assert_only_event_transfer_batch(OTHER(), ZERO(), recipient, token_ids, values);

    let balance_of_recipient_token_1_after = state.balance_of(recipient, TOKEN_ID);
    assert_eq!(balance_of_recipient_token_1_after, TOKEN_VALUE);
    let balance_of_recipient_token_2_after = state.balance_of(recipient, TOKEN_ID);
    assert_eq!(balance_of_recipient_token_2_after, TOKEN_VALUE);
}

#[test]
fn test_batch_mint_wac_to_account() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_account_with_salt(1);
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(OTHER());

    let balance_of_recipient_token_1_before = state.balance_of(recipient, TOKEN_ID);
    assert!(balance_of_recipient_token_1_before.is_zero());
    let balance_of_recipient_token_2_before = state.balance_of(recipient, TOKEN_ID + 100);
    assert!(balance_of_recipient_token_2_before.is_zero());

    state.batch_mint_with_acceptance_check(recipient, token_ids, values, data);
    assert_only_event_transfer_batch(OTHER(), ZERO(), recipient, token_ids, values);

    let balance_of_recipient_token_1_after = state.balance_of(recipient, TOKEN_ID);
    assert_eq!(balance_of_recipient_token_1_after, TOKEN_VALUE);
    let balance_of_recipient_token_2_after = state.balance_of(recipient, TOKEN_ID);
    assert_eq!(balance_of_recipient_token_2_after, TOKEN_VALUE);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_batch_mint_wac_to_zero() {
    let mut state = COMPONENT_STATE();
    let recipient = ZERO();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();

    state.batch_mint_with_acceptance_check(recipient, token_ids, values, data);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver',))]
fn test_batch_mint_wac_to_non_receiver() {
    let mut state = COMPONENT_STATE();
    let recipient = setup_src5();
    let data = array![].span();
    let (token_ids, values) = get_ids_and_values();

    state.batch_mint_with_acceptance_check(recipient, token_ids, values, data);
}

//
// burn & batch_burn
//

#[test]
fn test_burn() {
    let (mut state, owner) = setup();
    testing::set_caller_address(owner);

    let balance_of_owner = state.balance_of(owner, TOKEN_ID);
    assert_eq!(balance_of_owner, TOKEN_VALUE);

    state.burn(owner, TOKEN_ID, TOKEN_VALUE);
    assert_only_event_transfer_single(owner, owner, ZERO(), TOKEN_ID, TOKEN_VALUE);

    let balance_of_owner = state.balance_of(owner, TOKEN_ID);
    assert!(balance_of_owner.is_zero());
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender',))]
fn test_burn_from_zero() {
    let mut state = COMPONENT_STATE();
    state.burn(ZERO(), TOKEN_ID, TOKEN_VALUE);
}


#[test]
fn test_batch_burn() {
    let (mut state, owner) = setup();
    let (token_ids, values) = get_ids_and_values();
    testing::set_caller_address(owner);

    let balance_of_owner_token_1_before = state.balance_of(owner, TOKEN_ID);
    assert_eq!(balance_of_owner_token_1_before, TOKEN_VALUE);
    let balance_of_owner_token_2_before = state.balance_of(owner, TOKEN_ID + 100);
    assert_eq!(balance_of_owner_token_2_before, TOKEN_VALUE);

    state.batch_burn(owner, token_ids, values);
    assert_only_event_transfer_batch(owner, owner, ZERO(), token_ids, values);

    let balance_of_owner_token_1_after = state.balance_of(owner, TOKEN_ID);
    assert!(balance_of_owner_token_1_after.is_zero());
    let balance_of_owner_token_2_after = state.balance_of(owner, TOKEN_ID + 100);
    assert!(balance_of_owner_token_2_after.is_zero());
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender',))]
fn test_batch_burn_from_zero() {
    let mut state = COMPONENT_STATE();
    let (token_ids, values) = get_ids_and_values();
    state.batch_burn(ZERO(), token_ids, values);
}

//
// Helpers
//

fn assert_state_before_transfer_single(
    sender: ContractAddress, recipient: ContractAddress, token_id: u256
) {
    let state = COMPONENT_STATE();
    assert_eq!(state.balance_of(sender, token_id), TOKEN_VALUE);
    assert!(state.balance_of(recipient, token_id).is_zero());
}

fn assert_state_after_transfer_single(
    sender: ContractAddress, recipient: ContractAddress, token_id: u256
) {
    let state = COMPONENT_STATE();
    assert!(state.balance_of(sender, token_id).is_zero());
    assert_eq!(state.balance_of(recipient, token_id), TOKEN_VALUE);
}

fn assert_state_before_transfer_batch(
    sender: ContractAddress, recipient: ContractAddress, token_ids: Span<u256>
) {
    let state = COMPONENT_STATE();
    let mut index = 0;
    loop {
        if index == token_ids.len() {
            break;
        }
        let balance_of_sender = state.balance_of(sender, *token_ids.at(index));
        assert_eq!(balance_of_sender, TOKEN_VALUE);
        let balance_of_recipient = state.balance_of(recipient, *token_ids.at(index));
        assert!(balance_of_recipient.is_zero());

        index += 1;
    }
}

fn assert_state_before_transfer_from_zero_batch(
    sender: ContractAddress, recipient: ContractAddress, token_ids: Span<u256>
) {
    let state = COMPONENT_STATE();
    let mut index = 0;
    loop {
        if index == token_ids.len() {
            break;
        }
        let balance_of_sender = state.balance_of(sender, *token_ids.at(index));
        assert!(balance_of_sender.is_zero());
        let balance_of_recipient = state.balance_of(recipient, *token_ids.at(index));
        assert!(balance_of_recipient.is_zero());

        index += 1;
    }
}

fn assert_state_after_transfer_batch(
    sender: ContractAddress, recipient: ContractAddress, token_ids: Span<u256>
) {
    let state = COMPONENT_STATE();
    let mut index = 0;
    loop {
        if index == token_ids.len() {
            break;
        }
        let balance_of_sender = state.balance_of(sender, *token_ids.at(index));
        assert!(balance_of_sender.is_zero());
        let balance_of_recipient = state.balance_of(recipient, *token_ids.at(index));
        assert_eq!(balance_of_recipient, TOKEN_VALUE);

        index += 1;
    }
}

fn assert_state_after_transfer_to_zero_batch(
    sender: ContractAddress, recipient: ContractAddress, token_ids: Span<u256>
) {
    let state = COMPONENT_STATE();
    let mut index = 0;
    loop {
        if index == token_ids.len() {
            break;
        }
        let balance_of_sender = state.balance_of(sender, *token_ids.at(index));
        assert!(balance_of_sender.is_zero());
        let balance_of_recipient = state.balance_of(recipient, *token_ids.at(index));
        assert!(balance_of_recipient.is_zero());

        index += 1;
    }
}

fn assert_state_after_transfer_from_zero_batch(
    sender: ContractAddress, recipient: ContractAddress, token_ids: Span<u256>
) {
    let state = COMPONENT_STATE();
    let mut index = 0;
    loop {
        if index == token_ids.len() {
            break;
        }
        let balance_of_sender = state.balance_of(sender, *token_ids.at(index));
        assert!(balance_of_sender.is_zero());
        let balance_of_recipient = state.balance_of(recipient, *token_ids.at(index));
        assert_eq!(balance_of_recipient, TOKEN_VALUE);

        index += 1;
    }
}

fn assert_event_approval_for_all(
    owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ApprovalForAll>(ZERO()).unwrap();
    assert_eq!(event.account, owner);
    assert_eq!(event.operator, operator);
    assert_eq!(event.approved, approved);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(operator);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_transfer_single(
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_id: u256,
    value: u256
) {
    let event = utils::pop_log::<TransferSingle>(ZERO()).unwrap();
    assert_eq!(event.operator, operator);
    assert_eq!(event.from, from);
    assert_eq!(event.to, to);
    assert_eq!(event.id, token_id);
    assert_eq!(event.value, value);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(operator);
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_transfer_batch(
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_ids: Span<u256>,
    values: Span<u256>
) {
    let event = utils::pop_log::<TransferBatch>(ZERO()).unwrap();
    assert_eq!(event.operator, operator);
    assert_eq!(event.from, from);
    assert_eq!(event.to, to);
    assert_eq!(event.ids, token_ids);
    assert_eq!(event.values, values);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(operator);
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_transfer_single(
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_id: u256,
    value: u256
) {
    assert_event_transfer_single(operator, from, to, token_id, value);
    utils::assert_no_events_left(ZERO());
}

fn assert_only_event_transfer_batch(
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_ids: Span<u256>,
    values: Span<u256>
) {
    assert_event_transfer_batch(operator, from, to, token_ids, values);
    utils::assert_no_events_left(ZERO());
}

fn assert_only_event_approval_for_all(
    owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    assert_event_approval_for_all(owner, operator, approved);
    utils::assert_no_events_left(ZERO());
}

fn get_ids_and_values() -> (Span<u256>, Span<u256>) {
    let ids = array![TOKEN_ID, TOKEN_ID + 100].span();
    let values = array![TOKEN_VALUE, TOKEN_VALUE].span();
    (ids, values)
}

fn get_ids_and_split_values(split: u256) -> (Span<u256>, Span<u256>) {
    let ids = array![TOKEN_ID, TOKEN_ID].span();
    let values = array![TOKEN_VALUE - split, split].span();
    (ids, values)
}
