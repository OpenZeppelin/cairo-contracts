use openzeppelin::account::interface::ISRC6_ID;
use openzeppelin::account::utils::secp256k1::{
    DebugSecp256k1Point, Secp256k1PointSerde, Secp256k1PointPartialEq
};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::presets::EthAccountUpgradeable;
use openzeppelin::presets::interfaces::{
    EthAccountUpgradeableABIDispatcher, EthAccountUpgradeableABIDispatcherTrait
};
use openzeppelin::tests::account::test_eth_account::{
    assert_only_event_owner_added, assert_event_owner_removed
};
use openzeppelin::tests::account::test_eth_account::{
    deploy_erc20, SIGNED_TX_DATA, SignedTransactionData
};
use openzeppelin::tests::account::test_secp256k1::get_points;
use openzeppelin::tests::mocks::eth_account_mocks::SnakeEthAccountMock;
use openzeppelin::tests::upgrades::test_upgradeable::assert_only_event_upgraded;
use openzeppelin::tests::utils::constants::{
    CLASS_HASH_ZERO, ETH_PUBKEY, NEW_ETH_PUBKEY, SALT, ZERO, RECIPIENT, QUERY_VERSION,
    MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::account::Call;
use starknet::contract_address_const;
use starknet::testing;
use starknet::{ContractAddress, ClassHash};

fn CLASS_HASH() -> felt252 {
    EthAccountUpgradeable::TEST_CLASS_HASH
}

fn V2_CLASS_HASH() -> ClassHash {
    SnakeEthAccountMock::TEST_CLASS_HASH.try_into().unwrap()
}

//
// Setup
//

fn setup_dispatcher() -> EthAccountUpgradeableABIDispatcher {
    let mut calldata = array![];
    calldata.append_serde(ETH_PUBKEY());

    let target = utils::deploy(CLASS_HASH(), calldata);
    utils::drop_event(target);

    EthAccountUpgradeableABIDispatcher { contract_address: target }
}

fn setup_dispatcher_with_data(
    data: Option<@SignedTransactionData>
) -> EthAccountUpgradeableABIDispatcher {
    testing::set_version(MIN_TRANSACTION_VERSION);

    let mut calldata = array![];
    if data.is_some() {
        let data = data.unwrap();
        let mut serialized_signature = array![];
        data.signature.serialize(ref serialized_signature);

        testing::set_signature(serialized_signature.span());
        testing::set_transaction_hash(*data.transaction_hash);

        calldata.append_serde(*data.public_key);
    } else {
        calldata.append_serde(ETH_PUBKEY());
    }
    let address = utils::deploy(CLASS_HASH(), calldata);
    EthAccountUpgradeableABIDispatcher { contract_address: address }
}

//
// constructor
//

#[test]
fn test_constructor() {
    let mut state = EthAccountUpgradeable::contract_state_for_testing();

    EthAccountUpgradeable::constructor(ref state, ETH_PUBKEY());

    assert_only_event_owner_added(ZERO(), ETH_PUBKEY());

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
    let new_public_key = NEW_ETH_PUBKEY();

    testing::set_contract_address(dispatcher.contract_address);

    dispatcher.set_public_key(new_public_key);
    assert_eq!(dispatcher.get_public_key(), new_public_key);

    assert_event_owner_removed(dispatcher.contract_address, ETH_PUBKEY());
    assert_only_event_owner_added(dispatcher.contract_address, new_public_key);
}

#[test]
fn test_public_key_setter_and_getter_camel() {
    let dispatcher = setup_dispatcher();
    let new_public_key = NEW_ETH_PUBKEY();

    testing::set_contract_address(dispatcher.contract_address);

    dispatcher.setPublicKey(new_public_key);
    assert_eq!(dispatcher.getPublicKey(), new_public_key);

    assert_event_owner_removed(dispatcher.contract_address, ETH_PUBKEY());
    assert_only_event_owner_added(dispatcher.contract_address, new_public_key);
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized', 'ENTRYPOINT_FAILED'))]
fn test_set_public_key_different_account() {
    let dispatcher = setup_dispatcher();
    dispatcher.set_public_key(NEW_ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized', 'ENTRYPOINT_FAILED'))]
fn test_setPublicKey_different_account() {
    let dispatcher = setup_dispatcher();
    dispatcher.setPublicKey(NEW_ETH_PUBKEY());
}

//
// is_valid_signature & isValidSignature
//

fn is_valid_sig_dispatcher() -> (EthAccountUpgradeableABIDispatcher, felt252, Array<felt252>) {
    let dispatcher = setup_dispatcher();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut serialized_signature = array![];
    data.signature.serialize(ref serialized_signature);

    testing::set_contract_address(dispatcher.contract_address);
    dispatcher.set_public_key(data.public_key);

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
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    let is_valid = account.__validate_deploy__(CLASS_HASH(), SALT, ETH_PUBKEY());
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate_deploy__(CLASS_HASH(), SALT, ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_length() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![0x1];

    testing::set_signature(signature.span());

    account.__validate_deploy__(CLASS_HASH(), SALT, ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_empty_signature() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());
    account.__validate_deploy__(CLASS_HASH(), SALT, ETH_PUBKEY());
}

#[test]
fn test_validate_declare() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    let is_valid = account.__validate_declare__(CLASS_HASH());
    assert_eq!(is_valid, starknet::VALIDATED,);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher_with_data(Option::Some(@data));

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_length() {
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![0x1];

    testing::set_signature(signature.span());

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.', 'ENTRYPOINT_FAILED'))]
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

    let amount: u256 = 200;

    let mut calldata = array![];
    calldata.append_serde(RECIPIENT());
    calldata.append_serde(amount);

    let call = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata.span()
    };
    let mut calls = array![];
    calls.append(call);

    if version.is_some() {
        testing::set_version(version.unwrap());
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
#[should_panic(expected: ('EthAccount: invalid tx version', 'ENTRYPOINT_FAILED'))]
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
#[should_panic(expected: ('EthAccount: invalid signature', 'ENTRYPOINT_FAILED'))]
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
    let account = setup_dispatcher_with_data(Option::Some(@SIGNED_TX_DATA()));
    let mut calls = array![];

    let ret = account.__execute__(calls);

    assert!(ret.len().is_zero(), "Should have an empty response");
}

#[test]
#[should_panic(expected: ('EthAccount: invalid caller', 'ENTRYPOINT_FAILED'))]
fn test_account_called_from_contract() {
    let account = setup_dispatcher();
    let calls = array![];
    let caller = contract_address_const::<0x123>();

    testing::set_contract_address(account.contract_address);
    testing::set_caller_address(caller);

    account.__execute__(calls);
}


//
// upgrade
//

#[test]
#[should_panic(expected: ('EthAccount: unauthorized', 'ENTRYPOINT_FAILED',))]
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

    let dispatcher = EthAccountUpgradeableABIDispatcher { contract_address: v1.contract_address };
    dispatcher.getPublicKey();
}

#[test]
fn test_state_persists_after_upgrade() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    set_contract_and_caller(v1.contract_address);
    let dispatcher = EthAccountUpgradeableABIDispatcher { contract_address: v1.contract_address };

    let (point, _) = get_points();

    dispatcher.set_public_key(point);

    let camel_public_key = dispatcher.getPublicKey();
    assert_eq!(camel_public_key, point);

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
