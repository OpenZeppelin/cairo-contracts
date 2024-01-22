use openzeppelin::account::AccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin::account::interface::ISRC6_ID;
use openzeppelin::account::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::presets::Account;
use openzeppelin::tests::account::test_account::{
    deploy_erc20, SIGNED_TX_DATA, SignedTransactionData
};
use openzeppelin::tests::utils::constants::{
    PUBKEY, NEW_PUBKEY, SALT, ZERO, QUERY_OFFSET, QUERY_VERSION, RECIPIENT, MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::contract_address_const;
use starknet::testing;

fn CLASS_HASH() -> felt252 {
    Account::TEST_CLASS_HASH
}

//
// Setup
//

fn setup_dispatcher() -> AccountABIDispatcher {
    let mut calldata = array![PUBKEY];
    let target = utils::deploy(CLASS_HASH(), calldata);
    utils::drop_event(target);

    AccountABIDispatcher { contract_address: target }
}

fn setup_dispatcher_with_data(data: Option<@SignedTransactionData>) -> AccountABIDispatcher {
    testing::set_version(MIN_TRANSACTION_VERSION);

    let mut calldata = array![];
    if data.is_some() {
        let data = data.unwrap();
        testing::set_signature(array![*data.r, *data.s].span());
        testing::set_transaction_hash(*data.transaction_hash);

        calldata.append(*data.public_key);
    } else {
        calldata.append(PUBKEY);
    }
    let address = utils::deploy(CLASS_HASH(), calldata);
    AccountABIDispatcher { contract_address: address }
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut state = Account::contract_state_for_testing();
    Account::constructor(ref state, PUBKEY);

    assert_only_event_owner_added(PUBKEY, ZERO());

    assert(Account::PublicKeyImpl::get_public_key(@state) == PUBKEY, 'Should return PUBKEY');
    assert(Account::SRC5Impl::supports_interface(@state, ISRC5_ID), 'Should implement ISRC5');
    assert(Account::SRC5Impl::supports_interface(@state, ISRC6_ID), 'Should implement ISRC6');
}

//
// set_public_key & setPublicKey
//

#[test]
#[available_gas(2000000)]
fn test_public_key_setter_and_getter() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(dispatcher.contract_address);

    dispatcher.set_public_key(NEW_PUBKEY);
    assert(dispatcher.get_public_key() == NEW_PUBKEY, 'Should return NEW_PUBKEY');

    assert_event_owner_removed(PUBKEY, dispatcher.contract_address);
    assert_only_event_owner_added(NEW_PUBKEY, dispatcher.contract_address);
}

#[test]
#[available_gas(2000000)]
fn test_public_key_setter_and_getter_camel() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(dispatcher.contract_address);

    dispatcher.setPublicKey(NEW_PUBKEY);
    assert(dispatcher.getPublicKey() == NEW_PUBKEY, 'Should return NEW_PUBKEY');

    assert_event_owner_removed(PUBKEY, dispatcher.contract_address);
    assert_only_event_owner_added(NEW_PUBKEY, dispatcher.contract_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED'))]
fn test_set_public_key_different_account() {
    let dispatcher = setup_dispatcher();
    dispatcher.set_public_key(NEW_PUBKEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED'))]
fn test_setPublicKey_different_account() {
    let dispatcher = setup_dispatcher();
    dispatcher.setPublicKey(NEW_PUBKEY);
}

//
// is_valid_signature & isValidSignature
//

fn is_valid_sig_dispatcher() -> (AccountABIDispatcher, felt252, Array<felt252>) {
    let dispatcher = setup_dispatcher();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut signature = array![data.r, data.s];

    testing::set_contract_address(dispatcher.contract_address);
    dispatcher.set_public_key(data.public_key);

    (dispatcher, hash, signature)
}

#[test]
#[available_gas(2000000)]
fn test_is_valid_signature() {
    let (dispatcher, hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.is_valid_signature(hash, signature);
    assert(is_valid == starknet::VALIDATED, 'Should accept valid signature');
}

#[test]
#[available_gas(2000000)]
fn test_is_valid_signature_bad_sig() {
    let (dispatcher, hash, _) = is_valid_sig_dispatcher();

    let bad_signature = array![0x987, 0x564];

    let is_valid = dispatcher.is_valid_signature(hash, bad_signature.clone());
    assert(is_valid == 0, 'Should reject invalid signature');
}

#[test]
#[available_gas(2000000)]
fn test_isValidSignature() {
    let (dispatcher, hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.isValidSignature(hash, signature);
    assert(is_valid == starknet::VALIDATED, 'Should accept valid signature');
}

#[test]
#[available_gas(2000000)]
fn test_isValidSignature_bad_sig() {
    let (dispatcher, hash, _) = is_valid_sig_dispatcher();

    let bad_signature = array![0x987, 0x564];

    let is_valid = dispatcher.isValidSignature(hash, bad_signature);
    assert(is_valid == 0, 'Should reject invalid signature');
}

//
// supports_interface
//

#[test]
#[available_gas(2000000)]
fn test_supports_interface() {
    let dispatcher = setup_dispatcher();
    assert(dispatcher.supports_interface(ISRC5_ID), 'Should implement ISRC5');
    assert(dispatcher.supports_interface(ISRC6_ID), 'Should implement ISRC6');
    assert(!dispatcher.supports_interface(0x123), 'Should not implement 0x123');
}

//
// Entry points
//

#[test]
#[available_gas(2000000)]
fn test_validate_deploy() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    assert(
        account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY) == starknet::VALIDATED,
        'Should validate correctly'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_length() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![0x1];

    testing::set_signature(signature.span());

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_empty_signature() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());
    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[available_gas(2000000)]
fn test_validate_declare() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    assert(
        account.__validate_declare__(CLASS_HASH()) == starknet::VALIDATED,
        'Should validate correctly'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_length() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![0x1];

    testing::set_signature(signature.span());

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_empty_signature() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());

    account.__validate_declare__(CLASS_HASH());
}

fn test_execute_with_version(version: Option<felt252>) {
    let data = SIGNED_TX_DATA();
    let account = setup_dispatcher_with_data(Option::Some(@data));
    let erc20 = deploy_erc20(account.contract_address, 1000);

    // Craft call and add to calls array
    let amount: u256 = 200;

    let mut calldata = array![];
    calldata.append_serde(RECIPIENT());
    calldata.append_serde(amount);

    let call = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata
    };
    let mut calls = array![];
    calls.append(call);

    // Handle version for test
    if version.is_some() {
        testing::set_version(version.unwrap());
    }

    // Execute
    let ret = account.__execute__(calls);

    // Assert that the transfer was successful
    assert(erc20.balance_of(account.contract_address) == 800, 'Should have remainder');
    assert(erc20.balance_of(RECIPIENT()) == amount, 'Should have transferred');

    // Test return value
    let mut call_serialized_retval = *ret.at(0);
    let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
    assert(call_retval.unwrap(), 'Should have succeeded');
}

#[test]
#[available_gas(2000000)]
fn test_execute() {
    test_execute_with_version(Option::None(()));
}

#[test]
fn test_execute_future_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION + 1));
}

#[test]
#[available_gas(2000000)]
fn test_execute_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION));
}

#[test]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_query_version() {
    test_execute_with_version(Option::Some(QUERY_OFFSET));
}

#[test]
#[available_gas(2000000)]
fn test_execute_future_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION + 1));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION - 1));
}

#[test]
#[available_gas(2000000)]
fn test_validate() {
    let calls = array![];
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));

    assert(account.__validate__(calls) == starknet::VALIDATED, 'Should validate correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_invalid() {
    let calls = array![];
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
#[available_gas(20000000)]
fn test_multicall() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = contract_address_const::<0x123>();
    let recipient2 = contract_address_const::<0x456>();
    let mut calls = array![];

    // Craft call1
    let mut calldata1 = array![];
    let amount1: u256 = 300;
    calldata1.append_serde(recipient1);
    calldata1.append_serde(amount1);
    let call1 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata1
    };

    // Craft call2
    let mut calldata2 = array![];
    let amount2: u256 = 500;
    calldata2.append_serde(recipient2);
    calldata2.append_serde(amount2);
    let call2 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata2
    };

    // Bundle calls and exeute
    calls.append(call1);
    calls.append(call2);
    let ret = account.__execute__(calls);

    // Assert that the transfers were successful
    assert(erc20.balance_of(account.contract_address) == 200, 'Should have remainder');
    assert(erc20.balance_of(recipient1) == 300, 'Should have transferred');
    assert(erc20.balance_of(recipient2) == 500, 'Should have transferred');

    // Test return value
    let mut call1_serialized_retval = *ret.at(0);
    let mut call2_serialized_retval = *ret.at(1);
    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert(call1_retval.unwrap(), 'Should have succeeded');
    assert(call2_retval.unwrap(), 'Should have succeeded');
}

#[test]
#[available_gas(2000000)]
fn test_multicall_zero_calls() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut calls = array![];

    let ret = account.__execute__(calls);

    // Test return value
    assert(ret.len() == 0, 'Should have an empty response');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid caller', 'ENTRYPOINT_FAILED'))]
fn test_account_called_from_contract() {
    let account = setup_dispatcher();
    let calls = array![];
    let caller = contract_address_const::<0x123>();

    testing::set_contract_address(account.contract_address);
    testing::set_caller_address(caller);

    account.__execute__(calls);
}

//
// Helpers
//

fn assert_event_owner_removed(removed_owner_guid: felt252, contract: ContractAddress) {
    let event = utils::pop_log::<OwnerRemoved>(contract).unwrap();
    assert(event.removed_owner_guid == removed_owner_guid, 'Invalid `removed_owner_guid`');
}

fn assert_event_owner_added(new_owner_guid: felt252, contract: ContractAddress) {
    let event = utils::pop_log::<OwnerAdded>(contract).unwrap();
    assert(event.new_owner_guid == new_owner_guid, 'Invalid `new_owner_guid`');
}

fn assert_only_event_owner_added(new_owner_guid: felt252, contract: ContractAddress) {
    assert_event_owner_added(new_owner_guid, contract);
    utils::assert_no_events_left(contract);
}
