use core::num::traits::Zero;
use openzeppelin::account::interface::ISRC6_ID;
use openzeppelin::account::utils::secp256k1::{
    DebugSecp256k1Point, Secp256k1PointSerde, Secp256k1PointPartialEq
};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::presets::EthAccountUpgradeable;
use openzeppelin::presets::interfaces::eth_account::{
    EthAccountUpgradeableABISafeDispatcher, EthAccountUpgradeableABISafeDispatcherTrait
};
use openzeppelin::presets::interfaces::{
    EthAccountUpgradeableABIDispatcher, EthAccountUpgradeableABIDispatcherTrait
};
use openzeppelin::tests::account::ethereum::common::EthAccountSpyHelpers;
use openzeppelin::tests::account::ethereum::common::{
    deploy_erc20, SIGNED_TX_DATA, SignedTransactionData, get_accept_ownership_signature
};
use openzeppelin::tests::upgrades::common::UpgradeableSpyHelpers;
use openzeppelin::tests::utils::constants::secp256k1::KEY_PAIR;
use openzeppelin::tests::utils::constants::{
    CLASS_HASH_ZERO, ETH_PUBKEY, NEW_ETH_PUBKEY, SALT, ZERO, RECIPIENT, QUERY_VERSION,
    MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    cheat_signature_global, cheat_transaction_version_global, cheat_transaction_hash_global,
    start_cheat_caller_address
};
use snforge_std::{spy_events, test_address};
use starknet::ClassHash;
use starknet::SyscallResultTrait;
use starknet::account::Call;
use starknet::contract_address_const;
use starknet::secp256_trait::Secp256Trait;
use starknet::secp256k1::Secp256k1Point;

fn declare_v2_class_hash() -> ClassHash {
    utils::declare_class("SnakeEthAccountMock").class_hash
}

//
// Setup
//

fn setup_dispatcher() -> EthAccountUpgradeableABIDispatcher {
    let mut calldata = array![];
    calldata.append_serde(ETH_PUBKEY());

    let target = utils::declare_and_deploy("EthAccountUpgradeable", calldata);
    EthAccountUpgradeableABIDispatcher { contract_address: target }
}

fn setup_dispatcher_with_data(
    data: Option<@SignedTransactionData>
) -> (EthAccountUpgradeableABIDispatcher, felt252) {
    let mut calldata = array![];
    if let Option::Some(data) = data {
        let mut serialized_signature = array![];
        data.signature.serialize(ref serialized_signature);

        cheat_signature_global(serialized_signature.span());
        cheat_transaction_hash_global(*data.tx_hash);

        calldata.append_serde(*data.public_key);
    } else {
        calldata.append_serde(ETH_PUBKEY());
    }
    let contract_class = utils::declare_class("EthAccountUpgradeable");
    let address = utils::deploy(contract_class, calldata);
    let dispatcher = EthAccountUpgradeableABIDispatcher { contract_address: address };

    cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    start_cheat_caller_address(address, ZERO());

    (dispatcher, contract_class.class_hash.into())
}

//
// constructor
//

#[test]
fn test_constructor() {
    let mut state = EthAccountUpgradeable::contract_state_for_testing();
    let mut spy = spy_events();

    EthAccountUpgradeable::constructor(ref state, ETH_PUBKEY());

    spy.assert_only_event_owner_added(test_address(), ETH_PUBKEY());

    let public_key = EthAccountUpgradeable::EthAccountMixinImpl::get_public_key(@state);
    assert_eq!(public_key, ETH_PUBKEY());
    let supports_isrc5 = EthAccountUpgradeable::EthAccountMixinImpl::supports_interface(
        @state, ISRC5_ID
    );
    assert!(supports_isrc5);
    let supports_isrc6 = EthAccountUpgradeable::EthAccountMixinImpl::supports_interface(
        @state, ISRC6_ID
    );
    assert!(supports_isrc6);
}

//
// set_public_key & setPublicKey
//

#[test]
fn test_public_key_setter_and_getter() {
    let dispatcher = setup_dispatcher();
    let key_pair = KEY_PAIR();
    let contract_address = dispatcher.contract_address;
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, contract_address);

    let signature = get_accept_ownership_signature(contract_address, ETH_PUBKEY(), key_pair);
    dispatcher.set_public_key(key_pair.public_key, signature);
    assert_eq!(dispatcher.get_public_key(), key_pair.public_key);

    spy.assert_event_owner_removed(contract_address, ETH_PUBKEY());
    spy.assert_only_event_owner_added(contract_address, key_pair.public_key);
}

#[test]
fn test_public_key_setter_and_getter_camel() {
    let dispatcher = setup_dispatcher();
    let key_pair = KEY_PAIR();
    let contract_address = dispatcher.contract_address;
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, contract_address);

    let signature = get_accept_ownership_signature(contract_address, ETH_PUBKEY(), key_pair);
    dispatcher.setPublicKey(key_pair.public_key, signature);
    assert_eq!(dispatcher.getPublicKey(), key_pair.public_key);

    spy.assert_event_owner_removed(contract_address, ETH_PUBKEY());
    spy.assert_only_event_owner_added(contract_address, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_set_public_key_different_account() {
    let dispatcher = setup_dispatcher();
    dispatcher.set_public_key(NEW_ETH_PUBKEY(), array![].span());
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_setPublicKey_different_account() {
    let dispatcher = setup_dispatcher();
    dispatcher.setPublicKey(NEW_ETH_PUBKEY(), array![].span());
}

//
// is_valid_signature & isValidSignature
//

fn is_valid_sig_dispatcher() -> (EthAccountUpgradeableABIDispatcher, felt252, Array<felt252>) {
    let dispatcher = setup_dispatcher();
    let key_pair = KEY_PAIR();
    let contract_address = dispatcher.contract_address;
    let data = SIGNED_TX_DATA(key_pair);
    let hash = data.tx_hash;

    let mut serialized_signature = array![];
    data.signature.serialize(ref serialized_signature);

    start_cheat_caller_address(contract_address, contract_address);

    let signature = get_accept_ownership_signature(contract_address, ETH_PUBKEY(), key_pair);
    dispatcher.set_public_key(data.public_key, signature);

    (dispatcher, hash, serialized_signature)
}

#[test]
fn test_is_valid_signature() {
    let (dispatcher, hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.is_valid_signature(hash, signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
fn test_is_valid_signature_bad_sig() {
    let (dispatcher, hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.is_valid_signature(hash + 1, signature);
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
    let (dispatcher, hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.isValidSignature(hash + 1, signature);
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
    let (account, class_hash) = setup_dispatcher_with_data(
        Option::Some(@SIGNED_TX_DATA(KEY_PAIR()))
    );

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    let is_valid = account.__validate_deploy__(class_hash, SALT, ETH_PUBKEY());
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA(KEY_PAIR());
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate_deploy__(class_hash, SALT, ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_deploy_invalid_signature_length() {
    let (account, class_hash) = setup_dispatcher_with_data(
        Option::Some(@SIGNED_TX_DATA(KEY_PAIR()))
    );
    let mut signature = array![0x1];

    cheat_signature_global(signature.span());

    account.__validate_deploy__(class_hash, SALT, ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_deploy_empty_signature() {
    let (account, class_hash) = setup_dispatcher_with_data(
        Option::Some(@SIGNED_TX_DATA(KEY_PAIR()))
    );
    let empty_sig = array![];

    cheat_signature_global(empty_sig.span());
    account.__validate_deploy__(class_hash, SALT, ETH_PUBKEY());
}

#[test]
fn test_validate_declare() {
    let (account, class_hash) = setup_dispatcher_with_data(
        Option::Some(@SIGNED_TX_DATA(KEY_PAIR()))
    );

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    let is_valid = account.__validate_declare__(class_hash);
    assert_eq!(is_valid, starknet::VALIDATED,);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA(KEY_PAIR());
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_declare_invalid_signature_length() {
    let (account, class_hash) = setup_dispatcher_with_data(
        Option::Some(@SIGNED_TX_DATA(KEY_PAIR()))
    );
    let mut signature = array![0x1];

    cheat_signature_global(signature.span());

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_declare_empty_signature() {
    let (account, class_hash) = setup_dispatcher_with_data(
        Option::Some(@SIGNED_TX_DATA(KEY_PAIR()))
    );
    let empty_sig = array![];

    cheat_signature_global(empty_sig.span());

    account.__validate_declare__(class_hash);
}

fn test_execute_with_version(version: Option<felt252>) {
    let data = SIGNED_TX_DATA(KEY_PAIR());
    let (account, _) = setup_dispatcher_with_data(Option::Some(@data));
    let erc20 = deploy_erc20(account.contract_address, 1000);

    let amount: u256 = 200;

    let mut calldata = array![];
    calldata.append_serde(RECIPIENT());
    calldata.append_serde(amount);

    let call = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata.span()
    };
    let mut calls = array![];
    calls.append(call);

    if let Option::Some(version) = version {
        cheat_transaction_version_global(version);
    }

    let ret = account.__execute__(calls);

    assert_eq!(erc20.balance_of(account.contract_address), 800, "Should have remainder");
    assert_eq!(erc20.balance_of(RECIPIENT()), amount, "Should have transferred");

    let mut call_serialized_retval = *ret.at(0);
    let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
    assert!(call_retval.unwrap());
}

#[test]
fn test_execute() {
    test_execute_with_version(Option::None(()));
}

#[test]
fn test_execute_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION));
}

#[test]
#[should_panic(expected: ('EthAccount: invalid tx version',))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION - 1));
}

#[test]
fn test_validate() {
    let calls = array![];
    let (account, _) = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));

    let is_valid = account.__validate__(calls);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_validate_invalid() {
    let calls = array![];
    let mut data = SIGNED_TX_DATA(KEY_PAIR());
    data.tx_hash += 1;
    let (account, _) = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
fn test_multicall() {
    let (account, _) = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = contract_address_const::<0x123>();
    let recipient2 = contract_address_const::<0x456>();
    let mut calls = array![];

    let mut calldata1 = array![];
    let amount1: u256 = 300;
    calldata1.append_serde(recipient1);
    calldata1.append_serde(amount1);
    let call1 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata1.span()
    };

    let mut calldata2 = array![];
    let amount2: u256 = 500;
    calldata2.append_serde(recipient2);
    calldata2.append_serde(amount2);
    let call2 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata2.span()
    };

    calls.append(call1);
    calls.append(call2);
    let ret = account.__execute__(calls);

    assert_eq!(erc20.balance_of(account.contract_address), 200, "Should have remainder");
    assert_eq!(erc20.balance_of(recipient1), 300, "Should have transferred");
    assert_eq!(erc20.balance_of(recipient2), 500, "Should have transferred");

    let mut call1_serialized_retval = *ret.at(0);
    let mut call2_serialized_retval = *ret.at(1);
    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert!(call1_retval.unwrap());
    assert!(call2_retval.unwrap());
}

#[test]
fn test_multicall_zero_calls() {
    let (account, _) = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));
    let mut calls = array![];

    let ret = account.__execute__(calls);

    assert!(ret.len().is_zero(), "Should have an empty response");
}

#[test]
#[should_panic(expected: ('EthAccount: invalid caller',))]
fn test_account_called_from_contract() {
    let account = setup_dispatcher();
    let calls = array![];
    let caller = contract_address_const::<0x123>();

    start_cheat_caller_address(account.contract_address, caller);

    account.__execute__(calls);
}

//
// upgrade
//

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_upgrade_access_control() {
    let v1 = setup_dispatcher();
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero',))]
fn test_upgrade_with_class_hash_zero() {
    let v1 = setup_dispatcher();

    start_cheat_caller_address(v1.contract_address, v1.contract_address);
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
fn test_upgraded_event() {
    let v1 = setup_dispatcher();
    let v2_class_hash = declare_v2_class_hash();
    let mut spy = spy_events();

    start_cheat_caller_address(v1.contract_address, v1.contract_address);
    v1.upgrade(v2_class_hash);

    spy.assert_only_event_upgraded(v1.contract_address, v2_class_hash);
}

#[test]
#[feature("safe_dispatcher")]
fn test_v2_missing_camel_selector() {
    let v1 = setup_dispatcher();
    let v2_class_hash = declare_v2_class_hash();

    start_cheat_caller_address(v1.contract_address, v1.contract_address);
    v1.upgrade(v2_class_hash);

    let safe_dispatcher = EthAccountUpgradeableABISafeDispatcher {
        contract_address: v1.contract_address
    };
    let result = safe_dispatcher.getPublicKey();

    utils::assert_entrypoint_not_found_error(result, selector!("getPublicKey"), v1.contract_address)
}

#[test]
fn test_state_persists_after_upgrade() {
    let v1 = setup_dispatcher();
    let key_pair = KEY_PAIR();
    let v2_class_hash = declare_v2_class_hash();

    start_cheat_caller_address(v1.contract_address, v1.contract_address);
    let dispatcher = EthAccountUpgradeableABIDispatcher { contract_address: v1.contract_address };

    let signature = get_accept_ownership_signature(v1.contract_address, ETH_PUBKEY(), KEY_PAIR());
    dispatcher.set_public_key(key_pair.public_key, signature);

    let camel_public_key = dispatcher.getPublicKey();
    assert_eq!(camel_public_key, key_pair.public_key);

    v1.upgrade(v2_class_hash);
    let snake_public_key = dispatcher.get_public_key();

    assert_eq!(snake_public_key, camel_public_key);
}

//
// Helpers
//

fn get_points() -> (Secp256k1Point, Secp256k1Point) {
    let curve_size = Secp256Trait::<Secp256k1Point>::get_curve_size();
    let point_1 = Secp256Trait::secp256_ec_get_point_from_x_syscall(curve_size, true)
        .unwrap_syscall()
        .unwrap();
    let point_2 = Secp256Trait::secp256_ec_get_point_from_x_syscall(curve_size, false)
        .unwrap_syscall()
        .unwrap();

    (point_1, point_2)
}
