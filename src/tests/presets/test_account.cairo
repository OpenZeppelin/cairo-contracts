use openzeppelin::account::AccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin::account::interface::ISRC6_ID;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::presets::AccountUpgradeable;
use openzeppelin::presets::interfaces::{
    AccountUpgradeableABIDispatcher, AccountUpgradeableABIDispatcherTrait
};
use openzeppelin::tests::account::test_account::{
    assert_only_event_owner_added, assert_event_owner_removed
};
use openzeppelin::tests::account::test_account::{
    deploy_erc20, SIGNED_TX_DATA, SignedTransactionData
};
use openzeppelin::tests::mocks::account_mocks::SnakeAccountMock;
use openzeppelin::tests::upgrades::test_upgradeable::assert_only_event_upgraded;
use openzeppelin::tests::utils::constants::{
    PUBKEY, SALT, ZERO, CALLER, RECIPIENT, OTHER, QUERY_OFFSET, QUERY_VERSION,
    MIN_TRANSACTION_VERSION, CLASS_HASH_ZERO
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::account::Call;
use starknet::testing;
use starknet::{ContractAddress, ClassHash};

const NEW_PUBKEY: felt252 = 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7;

fn CLASS_HASH() -> felt252 {
    AccountUpgradeable::TEST_CLASS_HASH
}

fn V2_CLASS_HASH() -> ClassHash {
    SnakeAccountMock::TEST_CLASS_HASH.try_into().unwrap()
}

//
// Setup
//

fn setup_dispatcher() -> AccountUpgradeableABIDispatcher {
    let calldata = array![PUBKEY];
    let target = utils::deploy(CLASS_HASH(), calldata);
    utils::drop_event(target);

    AccountUpgradeableABIDispatcher { contract_address: target }
}

fn setup_dispatcher_with_data(
    data: Option<@SignedTransactionData>
) -> AccountUpgradeableABIDispatcher {
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
    AccountUpgradeableABIDispatcher { contract_address: address }
}

//
// constructor
//

#[test]
fn test_constructor() {
    let mut state = AccountUpgradeable::contract_state_for_testing();
    AccountUpgradeable::constructor(ref state, PUBKEY);

    assert_only_event_owner_added(ZERO(), PUBKEY);

    let public_key = AccountUpgradeable::AccountMixinImpl::get_public_key(@state);
    assert_eq!(public_key, PUBKEY);

    let supports_isrc5 = AccountUpgradeable::AccountMixinImpl::supports_interface(@state, ISRC5_ID);
    assert!(supports_isrc5);

    let supports_isrc6 = AccountUpgradeable::AccountMixinImpl::supports_interface(@state, ISRC6_ID);
    assert!(supports_isrc6);
}

//
// set_public_key & setPublicKey
//

#[test]
fn test_public_key_setter_and_getter() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(dispatcher.contract_address);

    dispatcher.set_public_key(NEW_PUBKEY, get_accept_ownership_signature());
    let public_key = dispatcher.get_public_key();
    assert_eq!(public_key, NEW_PUBKEY);

    assert_event_owner_removed(dispatcher.contract_address, PUBKEY);
    assert_only_event_owner_added(dispatcher.contract_address, NEW_PUBKEY);
}

#[test]
fn test_public_key_setter_and_getter_camel() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(dispatcher.contract_address);

    dispatcher.setPublicKey(NEW_PUBKEY, get_accept_ownership_signature());
    let public_key = dispatcher.getPublicKey();
    assert_eq!(public_key, NEW_PUBKEY);

    assert_event_owner_removed(dispatcher.contract_address, PUBKEY);
    assert_only_event_owner_added(dispatcher.contract_address, NEW_PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED'))]
fn test_set_public_key_different_account() {
    let dispatcher = setup_dispatcher();
    dispatcher.set_public_key(NEW_PUBKEY, get_accept_ownership_signature());
}

#[test]
#[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED'))]
fn test_setPublicKey_different_account() {
    let dispatcher = setup_dispatcher();
    dispatcher.setPublicKey(NEW_PUBKEY, get_accept_ownership_signature());
}

//
// is_valid_signature & isValidSignature
//

fn is_valid_sig_dispatcher() -> (AccountUpgradeableABIDispatcher, felt252, Array<felt252>) {
    let dispatcher = setup_dispatcher();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut signature = array![data.r, data.s];

    testing::set_contract_address(dispatcher.contract_address);
    dispatcher.set_public_key(data.public_key, get_accept_ownership_signature());

    (dispatcher, hash, signature)
}

#[test]
fn test_is_valid_signature() {
    let (dispatcher, hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.is_valid_signature(hash, signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
fn test_is_valid_signature_bad_sig() {
    let (dispatcher, hash, _) = is_valid_sig_dispatcher();

    let bad_signature = array![0x987, 0x564];

    let is_valid = dispatcher.is_valid_signature(hash, bad_signature.clone());
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

#[test]
fn test_isValidSignature() {
    let (dispatcher, hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.isValidSignature(hash, signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
fn test_isValidSignature_bad_sig() {
    let (dispatcher, hash, _) = is_valid_sig_dispatcher();

    let bad_signature = array![0x987, 0x564];

    let is_valid = dispatcher.isValidSignature(hash, bad_signature);
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

//
// supports_interface
//

#[test]
fn test_supports_interface() {
    let dispatcher = setup_dispatcher();
    let supports_isrc5 = dispatcher.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);
    let supports_isrc6 = dispatcher.supports_interface(ISRC6_ID);
    assert!(supports_isrc6);
    let doesnt_support_0x123 = !dispatcher.supports_interface(0x123);
    assert!(doesnt_support_0x123);
}

//
// Entry points
//

#[test]
fn test_validate_deploy() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    let is_valid = account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_length() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![0x1];

    testing::set_signature(signature.span());

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_empty_signature() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());
    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
fn test_validate_declare() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    let is_valid = account.__validate_declare__(CLASS_HASH());
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_length() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![0x1];

    testing::set_signature(signature.span());

    account.__validate_declare__(CLASS_HASH());
}

#[test]
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
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata.span()
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
    assert_eq!(erc20.balance_of(account.contract_address), 800, "Should have remainder");
    assert_eq!(erc20.balance_of(RECIPIENT()), amount, "Should have transferred");

    // Test return value
    let mut call_serialized_retval = *ret.at(0);
    let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
    assert!(call_retval.unwrap());
}

#[test]
fn test_execute() {
    test_execute_with_version(Option::None(()));
}

#[test]
fn test_execute_future_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION + 1));
}

#[test]
fn test_execute_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION));
}

#[test]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_query_version() {
    test_execute_with_version(Option::Some(QUERY_OFFSET));
}

#[test]
fn test_execute_future_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION + 1));
}

#[test]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION - 1));
}

#[test]
fn test_validate() {
    let calls = array![];
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));

    let is_valid = account.__validate__(calls);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_invalid() {
    let calls = array![];
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
fn test_multicall() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = RECIPIENT();
    let recipient2 = OTHER();
    let mut calls = array![];

    // Craft call1
    let mut calldata1 = array![];
    let amount1: u256 = 300;
    calldata1.append_serde(recipient1);
    calldata1.append_serde(amount1);
    let call1 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata1.span()
    };

    // Craft call2
    let mut calldata2 = array![];
    let amount2: u256 = 500;
    calldata2.append_serde(recipient2);
    calldata2.append_serde(amount2);
    let call2 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata2.span()
    };

    // Bundle calls and exeute
    calls.append(call1);
    calls.append(call2);
    let ret = account.__execute__(calls);

    // Assert that the transfers were successful
    assert_eq!(erc20.balance_of(account.contract_address), 200, "Should have remainder");
    assert_eq!(erc20.balance_of(recipient1), 300, "Should have transferred");
    assert_eq!(erc20.balance_of(recipient2), 500, "Should have transferred");

    // Test return value
    let mut call1_serialized_retval = *ret.at(0);
    let mut call2_serialized_retval = *ret.at(1);

    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    assert!(call1_retval.unwrap());

    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert!(call2_retval.unwrap());
}

#[test]
fn test_multicall_zero_calls() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut calls = array![];

    let response = account.__execute__(calls);
    assert!(response.is_empty());
}

#[test]
#[should_panic(expected: ('Account: invalid caller', 'ENTRYPOINT_FAILED'))]
fn test_account_called_from_contract() {
    let account = setup_dispatcher();
    let calls = array![];

    testing::set_contract_address(account.contract_address);
    testing::set_caller_address(CALLER());

    account.__execute__(calls);
}

//
// upgrade
//

#[test]
#[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_access_control() {
    let v1 = setup_dispatcher();
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_with_class_hash_zero() {
    let v1 = setup_dispatcher();

    set_contract_and_caller(v1.contract_address);
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
fn test_upgraded_event() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    set_contract_and_caller(v1.contract_address);
    v1.upgrade(v2_class_hash);

    assert_only_event_upgraded(v1.contract_address, v2_class_hash);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_v2_missing_camel_selector() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    set_contract_and_caller(v1.contract_address);
    v1.upgrade(v2_class_hash);

    let dispatcher = AccountUpgradeableABIDispatcher { contract_address: v1.contract_address };
    dispatcher.getPublicKey();
}

#[test]
fn test_state_persists_after_upgrade() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    set_contract_and_caller(v1.contract_address);
    let dispatcher = AccountUpgradeableABIDispatcher { contract_address: v1.contract_address };

    dispatcher.set_public_key(NEW_PUBKEY, get_accept_ownership_signature());

    let camel_public_key = dispatcher.getPublicKey();
    assert_eq!(camel_public_key, NEW_PUBKEY);

    v1.upgrade(v2_class_hash);
    let snake_public_key = dispatcher.get_public_key();

    assert_eq!(snake_public_key, camel_public_key);
}

//
// Helpers
//

fn set_contract_and_caller(address: ContractAddress) {
    testing::set_contract_address(address);
    testing::set_caller_address(address);
}

fn get_accept_ownership_signature() -> Span<felt252> {
    // 0x1d0f29f91d4d8242ae5646be871a7e64717eac611aed9ec15b423cb965817fb =
    // PoseidonTrait::new()
    //             .update('StarkNet Message')
    //             .update('accept_ownership')
    //             .update(dispatcher.contract_address.into())
    //             .update(PUBKEY)
    //             .finalize();

    // This signature was computed using starknet js sdk from the following values:
    // - private_key: '1234'
    // - public_key: 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7
    // - msg_hash: 0x1d0f29f91d4d8242ae5646be871a7e64717eac611aed9ec15b423cb965817fb
    array![
        0x5fcf4473fa8304093722b4999e53042db1a16ac4e51669203fe32c241b8ac4c,
        0x2350a661e77f26c304d9a896271977522410d015437dfea190148f224c6c30f
    ]
        .span()
}
