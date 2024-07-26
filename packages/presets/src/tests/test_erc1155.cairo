use core::num::traits::Zero;
use openzeppelin_access::tests::common::assert_event_ownership_transferred;
use openzeppelin_presets::ERC1155Upgradeable;
use openzeppelin_presets::interfaces::{
    ERC1155UpgradeableABIDispatcher, ERC1155UpgradeableABIDispatcherTrait
};
use openzeppelin_presets::tests::mocks::erc1155_mocks::SnakeERC1155Mock;
use openzeppelin_token::erc1155::interface::{IERC1155CamelDispatcher, IERC1155CamelDispatcherTrait};
use openzeppelin_token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin_token::erc1155;
use openzeppelin_token::tests::erc1155::common::{
    assert_only_event_transfer_single, assert_only_event_transfer_batch,
    assert_only_event_approval_for_all
};
use openzeppelin_token::tests::erc1155::common::{
    setup_account, setup_receiver, setup_camel_receiver, setup_account_with_salt, setup_src5
};
use openzeppelin_token::tests::erc1155::common::{get_ids_and_values, get_ids_and_split_values};
use openzeppelin_upgrades::tests::common::assert_only_event_upgraded;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::test_utils::constants::{
    EMPTY_DATA, ZERO, OWNER, RECIPIENT, CLASS_HASH_ZERO, OPERATOR, OTHER, TOKEN_ID, TOKEN_ID_2,
    TOKEN_VALUE, TOKEN_VALUE_2
};
use openzeppelin_utils::test_utils;
use starknet::testing;
use starknet::{ContractAddress, ClassHash};

fn V2_CLASS_HASH() -> ClassHash {
    SnakeERC1155Mock::TEST_CLASS_HASH.try_into().unwrap()
}

//
// Setup
//

fn setup_dispatcher_with_event() -> (ERC1155UpgradeableABIDispatcher, ContractAddress) {
    let uri: ByteArray = "URI";
    let mut calldata = array![];
    let mut token_ids = array![TOKEN_ID, TOKEN_ID_2];
    let mut values = array![TOKEN_VALUE, TOKEN_VALUE_2];

    let owner = setup_account();
    testing::set_contract_address(owner);

    calldata.append_serde(uri);
    calldata.append_serde(owner);
    calldata.append_serde(token_ids);
    calldata.append_serde(values);
    calldata.append_serde(owner);

    let address = test_utils::deploy(ERC1155Upgradeable::TEST_CLASS_HASH, calldata);
    (ERC1155UpgradeableABIDispatcher { contract_address: address }, owner)
}

fn setup_dispatcher() -> (ERC1155UpgradeableABIDispatcher, ContractAddress) {
    let (dispatcher, owner) = setup_dispatcher_with_event();
    test_utils::drop_event(dispatcher.contract_address); // `TransferOwnership`
    test_utils::drop_event(dispatcher.contract_address); // `Transfer`
    (dispatcher, owner)
}

//
// constructor
//

#[test]
fn test_constructor() {
    let (dispatcher, owner) = setup_dispatcher_with_event();

    assert_eq!(dispatcher.uri(TOKEN_ID), "URI");
    assert_eq!(dispatcher.balance_of(owner, TOKEN_ID), TOKEN_VALUE);
    assert_eq!(dispatcher.balance_of(owner, TOKEN_ID_2), TOKEN_VALUE_2);

    let supports_ierc1155 = dispatcher.supports_interface(erc1155::interface::IERC1155_ID);
    assert!(supports_ierc1155);

    let supports_ierc1155_metadata_uri = dispatcher
        .supports_interface(erc1155::interface::IERC1155_METADATA_URI_ID);
    assert!(supports_ierc1155_metadata_uri);

    let supports_isrc5 = dispatcher
        .supports_interface(openzeppelin_introspection::interface::ISRC5_ID);
    assert!(supports_isrc5);
}

//
// balance_of & balanceOf
//

#[test]
fn test_balance_of() {
    let (dispatcher, owner) = setup_dispatcher();

    let balance = dispatcher.balance_of(owner, TOKEN_ID);
    assert_eq!(balance, TOKEN_VALUE);
}

#[test]
fn test_balanceOf() {
    let (dispatcher, owner) = setup_dispatcher();

    let balance = dispatcher.balanceOf(owner, TOKEN_ID);
    assert_eq!(balance, TOKEN_VALUE);
}

//
// balance_of_batch & balanceOfBatch
//

#[test]
fn test_balance_of_batch() {
    let (dispatcher, owner) = setup_dispatcher();

    let accounts = array![owner, OTHER()].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID].span();

    let balances = dispatcher.balance_of_batch(accounts, token_ids);
    assert_eq!(*balances.at(0), TOKEN_VALUE);
    assert!((*balances.at(1)).is_zero());
}

#[test]
fn test_balanceOfBatch() {
    let (dispatcher, owner) = setup_dispatcher();

    let accounts = array![owner, OTHER()].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID].span();

    let balances = dispatcher.balanceOfBatch(accounts, token_ids);
    assert_eq!(*balances.at(0), TOKEN_VALUE);
    assert!((*balances.at(1)).is_zero());
}

#[test]
#[should_panic(expected: ('ERC1155: no equal array length', 'ENTRYPOINT_FAILED'))]
fn test_balance_of_batch_invalid_inputs() {
    let (dispatcher, owner) = setup_dispatcher();

    let accounts = array![owner, OTHER()].span();
    let token_ids = array![TOKEN_ID].span();

    dispatcher.balance_of_batch(accounts, token_ids);
}

#[test]
#[should_panic(expected: ('ERC1155: no equal array length', 'ENTRYPOINT_FAILED'))]
fn test_balanceOfBatch_invalid_inputs() {
    let (dispatcher, owner) = setup_dispatcher();

    let accounts = array![owner, OTHER()].span();
    let token_ids = array![TOKEN_ID].span();

    dispatcher.balanceOfBatch(accounts, token_ids);
}

//
// safe_transfer_from & safeTransferFrom
//

#[test]
fn test_safe_transfer_from_to_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_receiver();

    assert_state_before_transfer_single(dispatcher, owner, recipient, TOKEN_ID);

    dispatcher.safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_only_event_transfer_single(contract, owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(dispatcher, owner, recipient, TOKEN_ID);
}

#[test]
fn test_safe_transfer_from_to_camel_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_camel_receiver();

    assert_state_before_transfer_single(dispatcher, owner, recipient, TOKEN_ID);

    dispatcher.safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_only_event_transfer_single(contract, owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(dispatcher, owner, recipient, TOKEN_ID);
}

#[test]
fn test_safeTransferFrom_to_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_receiver();

    assert_state_before_transfer_single(dispatcher, owner, recipient, TOKEN_ID);

    dispatcher.safeTransferFrom(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_only_event_transfer_single(contract, owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(dispatcher, owner, recipient, TOKEN_ID);
}

#[test]
fn test_safeTransferFrom_to_camel_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_camel_receiver();

    assert_state_before_transfer_single(dispatcher, owner, recipient, TOKEN_ID);

    dispatcher.safeTransferFrom(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_only_event_transfer_single(contract, owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(dispatcher, owner, recipient, TOKEN_ID);
}

#[test]
fn test_safe_transfer_from_to_account() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_account_with_salt(1);

    assert_state_before_transfer_single(dispatcher, owner, recipient, TOKEN_ID);

    dispatcher.safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_only_event_transfer_single(contract, owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(dispatcher, owner, recipient, TOKEN_ID);
}

#[test]
fn test_safeTransferFrom_to_account() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_account_with_salt(1);

    assert_state_before_transfer_single(dispatcher, owner, recipient, TOKEN_ID);

    dispatcher.safeTransferFrom(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_only_event_transfer_single(contract, owner, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(dispatcher, owner, recipient, TOKEN_ID);
}

#[test]
fn test_safe_transfer_from_approved_operator() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_account_with_salt(1);
    let operator = OPERATOR();

    dispatcher.set_approval_for_all(operator, true);
    assert_only_event_approval_for_all(contract, owner, operator, true);

    assert_state_before_transfer_single(dispatcher, owner, recipient, TOKEN_ID);

    testing::set_contract_address(operator);
    dispatcher.safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_only_event_transfer_single(contract, operator, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(dispatcher, owner, recipient, TOKEN_ID);
}

#[test]
fn test_safeTransferFrom_approved_operator() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_account_with_salt(1);
    let operator = OPERATOR();

    dispatcher.set_approval_for_all(operator, true);
    assert_only_event_approval_for_all(contract, owner, operator, true);

    assert_state_before_transfer_single(dispatcher, owner, recipient, TOKEN_ID);

    testing::set_contract_address(operator);
    dispatcher.safeTransferFrom(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_only_event_transfer_single(contract, operator, owner, recipient, TOKEN_ID, TOKEN_VALUE);

    assert_state_after_transfer_single(dispatcher, owner, recipient, TOKEN_ID);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_from_zero() {
    let (dispatcher, owner) = setup_dispatcher();

    dispatcher.safe_transfer_from(ZERO(), owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_from_zero() {
    let (dispatcher, owner) = setup_dispatcher();

    dispatcher.safeTransferFrom(ZERO(), owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_zero() {
    let (dispatcher, owner) = setup_dispatcher();

    dispatcher.safe_transfer_from(owner, ZERO(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_zero() {
    let (dispatcher, owner) = setup_dispatcher();

    dispatcher.safeTransferFrom(owner, ZERO(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized operator', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_unauthorized() {
    let (dispatcher, owner) = setup_dispatcher();

    dispatcher.safe_transfer_from(OTHER(), owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized operator', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_unauthorized() {
    let (dispatcher, owner) = setup_dispatcher();

    dispatcher.safeTransferFrom(OTHER(), owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_insufficient_balance() {
    let (dispatcher, owner) = setup_dispatcher();

    dispatcher.safe_transfer_from(owner, OTHER(), TOKEN_ID, TOKEN_VALUE + 1, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_insufficient_balance() {
    let (dispatcher, owner) = setup_dispatcher();

    dispatcher.safeTransferFrom(owner, OTHER(), TOKEN_ID, TOKEN_VALUE + 1, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_non_account_non_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let non_receiver = setup_src5();

    dispatcher.safe_transfer_from(owner, non_receiver, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_non_account_non_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let non_receiver = setup_src5();

    dispatcher.safeTransferFrom(owner, non_receiver, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

//
// safe_batch_transfer_from & safeBatchTransferFrom
//

#[test]
fn test_safe_batch_transfer_from_to_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_receiver();
    let (token_ids, values) = get_ids_and_values();

    assert_state_before_transfer_batch(dispatcher, owner, recipient, token_ids, values);

    dispatcher.safe_batch_transfer_from(owner, recipient, token_ids, values, EMPTY_DATA());
    assert_only_event_transfer_batch(contract, owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(dispatcher, owner, recipient, token_ids, values);
}

#[test]
fn test_safe_batch_transfer_from_to_camel_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_camel_receiver();
    let (token_ids, values) = get_ids_and_values();

    assert_state_before_transfer_batch(dispatcher, owner, recipient, token_ids, values);

    dispatcher.safe_batch_transfer_from(owner, recipient, token_ids, values, EMPTY_DATA());
    assert_only_event_transfer_batch(contract, owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(dispatcher, owner, recipient, token_ids, values);
}

#[test]
fn test_safeBatchTransferFrom_to_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_receiver();
    let (token_ids, values) = get_ids_and_values();

    assert_state_before_transfer_batch(dispatcher, owner, recipient, token_ids, values);

    dispatcher.safeBatchTransferFrom(owner, recipient, token_ids, values, EMPTY_DATA());
    assert_only_event_transfer_batch(contract, owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(dispatcher, owner, recipient, token_ids, values);
}

#[test]
fn test_safeBatchTransferFrom_to_camel_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_camel_receiver();
    let (token_ids, values) = get_ids_and_values();

    assert_state_before_transfer_batch(dispatcher, owner, recipient, token_ids, values);

    dispatcher.safeBatchTransferFrom(owner, recipient, token_ids, values, EMPTY_DATA());
    assert_only_event_transfer_batch(contract, owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(dispatcher, owner, recipient, token_ids, values);
}

#[test]
fn test_safe_batch_transfer_from_to_account() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_account_with_salt(1);
    let (token_ids, values) = get_ids_and_values();

    assert_state_before_transfer_batch(dispatcher, owner, recipient, token_ids, values);

    dispatcher.safe_batch_transfer_from(owner, recipient, token_ids, values, EMPTY_DATA());
    assert_only_event_transfer_batch(contract, owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(dispatcher, owner, recipient, token_ids, values);
}

#[test]
fn test_safeBatchTransferFrom_to_account() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_account_with_salt(1);
    let (token_ids, values) = get_ids_and_values();

    assert_state_before_transfer_batch(dispatcher, owner, recipient, token_ids, values);

    dispatcher.safeBatchTransferFrom(owner, recipient, token_ids, values, EMPTY_DATA());
    assert_only_event_transfer_batch(contract, owner, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(dispatcher, owner, recipient, token_ids, values);
}


#[test]
fn test_safe_batch_transfer_from_approved_operator() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_account_with_salt(1);
    let operator = OPERATOR();
    let (token_ids, values) = get_ids_and_values();

    dispatcher.set_approval_for_all(operator, true);
    assert_only_event_approval_for_all(contract, owner, operator, true);

    assert_state_before_transfer_batch(dispatcher, owner, recipient, token_ids, values);

    testing::set_contract_address(operator);
    dispatcher.safe_batch_transfer_from(owner, recipient, token_ids, values, EMPTY_DATA());
    assert_only_event_transfer_batch(contract, operator, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(dispatcher, owner, recipient, token_ids, values);
}

#[test]
fn test_safeBatchTransferFrom_approved_operator() {
    let (dispatcher, owner) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    let recipient = setup_account_with_salt(1);
    let operator = OPERATOR();
    let (token_ids, values) = get_ids_and_values();

    dispatcher.set_approval_for_all(operator, true);
    assert_only_event_approval_for_all(contract, owner, operator, true);

    assert_state_before_transfer_batch(dispatcher, owner, recipient, token_ids, values);
    testing::set_contract_address(operator);
    dispatcher.safeBatchTransferFrom(owner, recipient, token_ids, values, EMPTY_DATA());
    assert_only_event_transfer_batch(contract, operator, owner, recipient, token_ids, values);

    assert_state_after_transfer_batch(dispatcher, owner, recipient, token_ids, values);
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender', 'ENTRYPOINT_FAILED'))]
fn test_safe_batch_transfer_from_from_zero() {
    let (dispatcher, owner) = setup_dispatcher();
    let (token_ids, values) = get_ids_and_values();

    dispatcher.safe_batch_transfer_from(ZERO(), owner, token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: invalid sender', 'ENTRYPOINT_FAILED'))]
fn test_safeBatchTransferFrom_from_zero() {
    let (dispatcher, owner) = setup_dispatcher();
    let (token_ids, values) = get_ids_and_values();

    dispatcher.safeBatchTransferFrom(ZERO(), owner, token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safe_batch_transfer_from_to_zero() {
    let (dispatcher, owner) = setup_dispatcher();
    let (token_ids, values) = get_ids_and_values();

    dispatcher.safe_batch_transfer_from(owner, ZERO(), token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safeBatchTransferFrom_to_zero() {
    let (dispatcher, owner) = setup_dispatcher();
    let (token_ids, values) = get_ids_and_values();

    dispatcher.safeBatchTransferFrom(owner, ZERO(), token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized operator', 'ENTRYPOINT_FAILED'))]
fn test_safe_batch_transfer_from_unauthorized() {
    let (dispatcher, owner) = setup_dispatcher();
    let (token_ids, values) = get_ids_and_values();

    dispatcher.safe_batch_transfer_from(OTHER(), owner, token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: unauthorized operator', 'ENTRYPOINT_FAILED'))]
fn test_safeBatchTransferFrom_unauthorized() {
    let (dispatcher, owner) = setup_dispatcher();
    let (token_ids, values) = get_ids_and_values();

    dispatcher.safeBatchTransferFrom(OTHER(), owner, token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance', 'ENTRYPOINT_FAILED'))]
fn test_safe_batch_transfer_from_insufficient_balance() {
    let (dispatcher, owner) = setup_dispatcher();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE + 1, TOKEN_VALUE_2].span();

    dispatcher.safe_batch_transfer_from(owner, OTHER(), token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: insufficient balance', 'ENTRYPOINT_FAILED'))]
fn test_safeBatchTransferFrom_insufficient_balance() {
    let (dispatcher, owner) = setup_dispatcher();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE + 1, TOKEN_VALUE_2].span();

    dispatcher.safeBatchTransferFrom(owner, OTHER(), token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safe_batch_transfer_from_non_account_non_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let (token_ids, values) = get_ids_and_split_values(5);
    let non_receiver = setup_src5();

    dispatcher.safe_batch_transfer_from(owner, non_receiver, token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: ('ERC1155: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safeBatchTransferFrom_non_account_non_receiver() {
    let (dispatcher, owner) = setup_dispatcher();
    let (token_ids, values) = get_ids_and_split_values(5);
    let non_receiver = setup_src5();

    dispatcher.safeBatchTransferFrom(owner, non_receiver, token_ids, values, EMPTY_DATA());
}

//
// set_approval_for_all & is_approved_for_all
//

#[test]
fn test_set_approval_for_all_and_is_approved_for_all() {
    let (dispatcher, _) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    testing::set_contract_address(OWNER());

    let not_approved_for_all = !dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(not_approved_for_all);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    assert_only_event_approval_for_all(contract, OWNER(), OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);

    dispatcher.set_approval_for_all(OPERATOR(), false);
    assert_only_event_approval_for_all(contract, OWNER(), OPERATOR(), false);

    let not_approved_for_all = !dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(not_approved_for_all);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval', 'ENTRYPOINT_FAILED'))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OWNER(), true);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval', 'ENTRYPOINT_FAILED'))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OWNER(), false);
}

//
// setApprovalForAll & isApprovedForAll
//

#[test]
fn test_setApprovalForAll_and_isApprovedForAll() {
    let (dispatcher, _) = setup_dispatcher();
    let contract = dispatcher.contract_address;
    testing::set_contract_address(OWNER());

    let not_approved_for_all = !dispatcher.isApprovedForAll(OWNER(), OPERATOR());
    assert!(not_approved_for_all);

    dispatcher.setApprovalForAll(OPERATOR(), true);
    assert_only_event_approval_for_all(contract, OWNER(), OPERATOR(), true);

    let is_approved_for_all = dispatcher.isApprovedForAll(OWNER(), OPERATOR());
    assert!(is_approved_for_all);

    dispatcher.setApprovalForAll(OPERATOR(), false);
    assert_only_event_approval_for_all(contract, OWNER(), OPERATOR(), false);

    let not_approved_for_all = !dispatcher.isApprovedForAll(OWNER(), OPERATOR());
    assert!(not_approved_for_all);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval', 'ENTRYPOINT_FAILED'))]
fn test_setApprovalForAll_owner_equal_operator_true() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OWNER(), true);
}

#[test]
#[should_panic(expected: ('ERC1155: self approval', 'ENTRYPOINT_FAILED'))]
fn test_setApprovalForAll_owner_equal_operator_false() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.setApprovalForAll(OWNER(), false);
}

//
// transfer_ownership & transferOwnership
//

#[test]
fn test_transfer_ownership() {
    let (dispatcher, owner) = setup_dispatcher();
    testing::set_contract_address(owner);
    dispatcher.transfer_ownership(OTHER());

    assert_event_ownership_transferred(dispatcher.contract_address, owner, OTHER());
    assert_eq!(dispatcher.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_to_zero() {
    let (dispatcher, owner) = setup_dispatcher();
    testing::set_contract_address(owner);
    dispatcher.transfer_ownership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_from_zero() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.transfer_ownership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_from_nonowner() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transfer_ownership(OTHER());
}

#[test]
fn test_transferOwnership() {
    let (dispatcher, owner) = setup_dispatcher();
    testing::set_contract_address(owner);
    dispatcher.transferOwnership(OTHER());

    assert_event_ownership_transferred(dispatcher.contract_address, owner, OTHER());
    assert_eq!(dispatcher.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_to_zero() {
    let (dispatcher, owner) = setup_dispatcher();
    testing::set_contract_address(owner);
    dispatcher.transferOwnership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_from_zero() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.transferOwnership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_from_nonowner() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transferOwnership(OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
fn test_renounce_ownership() {
    let (dispatcher, owner) = setup_dispatcher();
    testing::set_contract_address(owner);
    dispatcher.renounce_ownership();

    assert_event_ownership_transferred(dispatcher.contract_address, owner, ZERO());
    assert!(dispatcher.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_renounce_ownership_from_zero_address() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.renounce_ownership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_renounce_ownership_from_nonowner() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.renounce_ownership();
}

#[test]
fn test_renounceOwnership() {
    let (dispatcher, owner) = setup_dispatcher();
    testing::set_contract_address(owner);
    dispatcher.renounceOwnership();

    assert_event_ownership_transferred(dispatcher.contract_address, owner, ZERO());
    assert!(dispatcher.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_renounceOwnership_from_zero_address() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.renounceOwnership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_renounceOwnership_from_nonowner() {
    let (dispatcher, _) = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.renounceOwnership();
}

//
// upgrade
//

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_unauthorized() {
    let (v1, _) = setup_dispatcher();
    testing::set_contract_address(OTHER());
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_with_class_hash_zero() {
    let (v1, owner) = setup_dispatcher();

    testing::set_contract_address(owner);
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
fn test_upgraded_event() {
    let (v1, owner) = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(owner);
    v1.upgrade(v2_class_hash);

    assert_only_event_upgraded(v1.contract_address, v2_class_hash);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_v2_missing_camel_selector() {
    let (v1, owner) = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(owner);
    v1.upgrade(v2_class_hash);

    let dispatcher = IERC1155CamelDispatcher { contract_address: v1.contract_address };
    dispatcher.balanceOf(owner, TOKEN_ID);
}

#[test]
fn test_state_persists_after_upgrade() {
    let (v1, owner) = setup_dispatcher();
    let recipient = setup_receiver();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(owner);
    v1.safeTransferFrom(owner, recipient, TOKEN_ID, TOKEN_VALUE, array![].span());

    // Check RECIPIENT balance v1
    let camel_balance = v1.balanceOf(recipient, TOKEN_ID);
    assert_eq!(camel_balance, TOKEN_VALUE);

    v1.upgrade(v2_class_hash);

    // Check RECIPIENT balance v2
    let v2 = IERC1155Dispatcher { contract_address: v1.contract_address };
    let snake_balance = v2.balance_of(recipient, TOKEN_ID);
    assert_eq!(snake_balance, camel_balance);
}

//
// Helpers
//

fn assert_state_before_transfer_single(
    dispatcher: ERC1155UpgradeableABIDispatcher,
    sender: ContractAddress,
    recipient: ContractAddress,
    token_id: u256
) {
    assert_eq!(dispatcher.balance_of(sender, token_id), TOKEN_VALUE);
    assert!(dispatcher.balance_of(recipient, token_id).is_zero());
}

fn assert_state_after_transfer_single(
    dispatcher: ERC1155UpgradeableABIDispatcher,
    sender: ContractAddress,
    recipient: ContractAddress,
    token_id: u256
) {
    assert!(dispatcher.balance_of(sender, token_id).is_zero());
    assert_eq!(dispatcher.balance_of(recipient, token_id), TOKEN_VALUE);
}

fn assert_state_before_transfer_batch(
    dispatcher: ERC1155UpgradeableABIDispatcher,
    sender: ContractAddress,
    recipient: ContractAddress,
    token_ids: Span<u256>,
    values: Span<u256>
) {
    let mut index = 0;
    loop {
        if index == token_ids.len() {
            break;
        }
        let balance_of_sender = dispatcher.balance_of(sender, *token_ids.at(index));
        assert_eq!(balance_of_sender, *values.at(index));
        let balance_of_recipient = dispatcher.balance_of(recipient, *token_ids.at(index));
        assert!(balance_of_recipient.is_zero());

        index += 1;
    }
}

fn assert_state_after_transfer_batch(
    dispatcher: ERC1155UpgradeableABIDispatcher,
    sender: ContractAddress,
    recipient: ContractAddress,
    token_ids: Span<u256>,
    values: Span<u256>
) {
    let mut index = 0;
    loop {
        if index == token_ids.len() {
            break;
        }
        let balance_of_sender = dispatcher.balance_of(sender, *token_ids.at(index));
        assert!(balance_of_sender.is_zero());
        let balance_of_recipient = dispatcher.balance_of(recipient, *token_ids.at(index));
        assert_eq!(balance_of_recipient, *values.at(index));

        index += 1;
    }
}
