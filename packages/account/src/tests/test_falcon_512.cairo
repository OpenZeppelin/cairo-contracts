use core::num::traits::Zero;
use openzeppelin_interfaces::accounts::{
    IDeclarerDispatcher, IDeclarerDispatcherTrait, IFeltArrayDeployableDispatcher,
    IFeltArrayDeployableDispatcherTrait, IFeltArrayPublicKeyDispatcher,
    IFeltArrayPublicKeyDispatcherTrait, ISRC6Dispatcher, ISRC6DispatcherTrait, ISRC6_ID,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use openzeppelin_test_common::mocks::simple::{ISimpleMockDispatcher, ISimpleMockDispatcherTrait};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{
    CALLER, MIN_TRANSACTION_VERSION, QUERY_OFFSET, QUERY_VERSION, SALT, ZERO,
};
use snforge_std::{
    start_cheat_caller_address, start_cheat_signature_global, start_cheat_transaction_hash_global,
    start_cheat_transaction_version_global,
};
use starknet::ContractAddress;
use starknet::account::Call;
use crate::falcon_512::{
    DIRECT_SIGNATURE_FELTS, Falcon512ShakeDirectVerifier, Falcon512ShakeVerifier, PUBLIC_KEY_FELTS,
    SIGNATURE_FELTS,
};
use super::falcon_512_fixture::{msg, public_key, signature};

const Q_POW_9: felt252 = 6392178558614694273495691177456939009;
const TWO_POW_160: felt252 = 0x10000000000000000000000000000000000000000;

fn copy_prefix(mut values: Span<felt252>, length: u32) -> Array<felt252> {
    let mut output = array![];
    let mut index = 0;
    while index != length {
        output.append(*values.pop_front().unwrap());
        index += 1;
    }
    output
}

fn with_replaced(mut values: Span<felt252>, target: u32, replacement: felt252) -> Array<felt252> {
    let mut output = array![];
    let mut index = 0;
    while let Some(value) = values.pop_front() {
        if index == target {
            output.append(replacement);
        } else {
            output.append(*value);
        }
        index += 1;
    }
    output
}

fn with_swapped(values: Span<felt252>, first: u32, second: u32) -> Array<felt252> {
    let first_value = *values.at(first);
    let second_value = *values.at(second);
    with_replaced(with_replaced(values, first, second_value).span(), second, first_value)
}

fn with_appended(mut values: Span<felt252>, value: felt252) -> Array<felt252> {
    let mut output = array![];
    while let Some(current) = values.pop_front() {
        output.append(*current);
    }
    output.append(value);
    output
}

fn direct_signature() -> Array<felt252> {
    copy_prefix(signature().span(), DIRECT_SIGNATURE_FELTS)
}

fn deploy_account(contract_name: ByteArray) -> (ContractAddress, felt252) {
    let contract_class = utils::declare_class(contract_name);
    let mut calldata = array![];
    public_key().serialize(ref calldata);
    let contract_address = utils::deploy(contract_class, calldata);
    (contract_address, contract_class.class_hash.into())
}

fn setup_transaction(
    contract_address: ContractAddress,
    tx_hash: felt252,
    tx_signature: Array<felt252>,
    version: felt252,
) {
    start_cheat_signature_global(tx_signature.span());
    start_cheat_transaction_hash_global(tx_hash);
    start_cheat_transaction_version_global(version);
    start_cheat_caller_address(contract_address, ZERO);
}

fn execute_increase(
    account: ISRC6Dispatcher, target: ContractAddress, amount: felt252, version: felt252,
) {
    start_cheat_transaction_version_global(version);
    let calldata = array![amount];
    let call = Call {
        to: target, selector: selector!("increase_balance"), calldata: calldata.span(),
    };
    account.__execute__(array![call]);
}

#[test]
fn test_verifiers_accept_reference_signature_and_reject_cross_layout() {
    let key = public_key();
    let hint_signature = signature();
    let direct_signature = direct_signature();

    assert!(Falcon512ShakeVerifier::verify(msg(), key.span(), hint_signature.span()));
    assert!(Falcon512ShakeDirectVerifier::verify(msg(), key.span(), direct_signature.span()));
    assert!(!Falcon512ShakeVerifier::verify(msg(), key.span(), direct_signature.span()));
    assert!(!Falcon512ShakeDirectVerifier::verify(msg(), key.span(), hint_signature.span()));
}

#[test]
fn test_hint_verifier_rejects_all_malformed_layout_branches() {
    let key = public_key();
    let valid_signature = signature();

    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), key.span().slice(0, PUBLIC_KEY_FELTS - 1), valid_signature.span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), with_appended(key.span(), 0).span(), valid_signature.span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), key.span(), valid_signature.span().slice(0, SIGNATURE_FELTS - 1),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), key.span(), with_appended(valid_signature.span(), 0).span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), with_replaced(key.span(), 0, Q_POW_9).span(), valid_signature.span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), key.span(), with_replaced(valid_signature.span(), 0, Q_POW_9).span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), key.span(), with_replaced(valid_signature.span(), 31, Q_POW_9).span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), key.span(), with_replaced(valid_signature.span(), 29, TWO_POW_160).span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), key.span(), with_replaced(valid_signature.span(), 30, TWO_POW_160).span(),
        ),
    );
}

#[test]
fn test_hint_verifier_rejects_every_authenticated_input_tamper() {
    let key = public_key();
    let valid_signature = signature();

    assert!(!Falcon512ShakeVerifier::verify(msg() + 1, key.span(), valid_signature.span()));
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), with_swapped(key.span(), 0, 1).span(), valid_signature.span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(), key.span(), with_swapped(valid_signature.span(), 0, 1).span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(),
            key.span(),
            with_replaced(valid_signature.span(), 29, *valid_signature.at(29) + 1).span(),
        ),
    );
    assert!(
        !Falcon512ShakeVerifier::verify(
            msg(),
            key.span(),
            with_replaced(valid_signature.span(), 31, *valid_signature.at(31) + 1).span(),
        ),
    );
}

#[test]
fn test_direct_verifier_rejects_all_malformed_layout_branches() {
    let key = public_key();
    let valid_signature = direct_signature();

    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), key.span().slice(0, PUBLIC_KEY_FELTS - 1), valid_signature.span(),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), with_appended(key.span(), 0).span(), valid_signature.span(),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), key.span(), valid_signature.span().slice(0, DIRECT_SIGNATURE_FELTS - 1),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), key.span(), with_appended(valid_signature.span(), 0).span(),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), with_replaced(key.span(), 0, Q_POW_9).span(), valid_signature.span(),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), key.span(), with_replaced(valid_signature.span(), 0, Q_POW_9).span(),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), key.span(), with_replaced(valid_signature.span(), 29, TWO_POW_160).span(),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), key.span(), with_replaced(valid_signature.span(), 30, TWO_POW_160).span(),
        ),
    );
}

#[test]
fn test_direct_verifier_rejects_every_authenticated_input_tamper() {
    let key = public_key();
    let valid_signature = direct_signature();

    assert!(!Falcon512ShakeDirectVerifier::verify(msg() + 1, key.span(), valid_signature.span()));
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), with_swapped(key.span(), 0, 1).span(), valid_signature.span(),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(), key.span(), with_swapped(valid_signature.span(), 0, 1).span(),
        ),
    );
    assert!(
        !Falcon512ShakeDirectVerifier::verify(
            msg(),
            key.span(),
            with_replaced(valid_signature.span(), 29, *valid_signature.at(29) + 1).span(),
        ),
    );
}

#[test]
fn test_hint_tampering_does_not_change_direct_signature() {
    let key = public_key();
    let valid_signature = signature();
    let tampered = with_replaced(valid_signature.span(), 31, *valid_signature.at(31) + 1);

    assert!(!Falcon512ShakeVerifier::verify(msg(), key.span(), tampered.span()));
    assert!(
        Falcon512ShakeDirectVerifier::verify(
            msg(), key.span(), copy_prefix(tampered.span(), DIRECT_SIGNATURE_FELTS).span(),
        ),
    );
}

#[test]
fn test_accounts_expose_exact_public_key_and_interfaces() {
    let (hint_address, _) = deploy_account("Falcon512ShakeAccount");
    let (direct_address, _) = deploy_account("Falcon512ShakeDirectAccount");

    for address in [hint_address, direct_address].span() {
        let key_dispatcher = IFeltArrayPublicKeyDispatcher { contract_address: *address };
        assert_eq!(key_dispatcher.get_public_key().span(), public_key().span());

        let src5 = ISRC5Dispatcher { contract_address: *address };
        assert!(src5.supports_interface(ISRC5_ID));
        assert!(src5.supports_interface(ISRC6_ID));
        assert!(!src5.supports_interface(0x123456));
    }
}

#[test]
fn test_accounts_is_valid_signature_return_convention() {
    let (hint_address, _) = deploy_account("Falcon512ShakeAccount");
    let (direct_address, _) = deploy_account("Falcon512ShakeDirectAccount");
    let hint = ISRC6Dispatcher { contract_address: hint_address };
    let direct = ISRC6Dispatcher { contract_address: direct_address };

    assert_eq!(hint.is_valid_signature(msg(), signature()), starknet::VALIDATED);
    assert!(hint.is_valid_signature(msg() + 1, signature()).is_zero());
    assert!(hint.is_valid_signature(msg(), direct_signature()).is_zero());

    assert_eq!(direct.is_valid_signature(msg(), direct_signature()), starknet::VALIDATED);
    assert!(direct.is_valid_signature(msg() + 1, direct_signature()).is_zero());
    assert!(direct.is_valid_signature(msg(), signature()).is_zero());
}

#[test]
fn test_all_validation_entrypoints_accept_hint_account_signature() {
    let (address, class_hash) = deploy_account("Falcon512ShakeAccount");
    setup_transaction(address, msg(), signature(), MIN_TRANSACTION_VERSION);

    let src6 = ISRC6Dispatcher { contract_address: address };
    let declarer = IDeclarerDispatcher { contract_address: address };
    let deployable = IFeltArrayDeployableDispatcher { contract_address: address };
    assert_eq!(src6.__validate__(array![]), starknet::VALIDATED);
    assert_eq!(declarer.__validate_declare__(class_hash), starknet::VALIDATED);
    assert_eq!(deployable.__validate_deploy__(class_hash, SALT, public_key()), starknet::VALIDATED);
}

#[test]
fn test_all_validation_entrypoints_accept_direct_account_signature() {
    let (address, class_hash) = deploy_account("Falcon512ShakeDirectAccount");
    setup_transaction(address, msg(), direct_signature(), MIN_TRANSACTION_VERSION);

    let src6 = ISRC6Dispatcher { contract_address: address };
    let declarer = IDeclarerDispatcher { contract_address: address };
    let deployable = IFeltArrayDeployableDispatcher { contract_address: address };
    assert_eq!(src6.__validate__(array![]), starknet::VALIDATED);
    assert_eq!(declarer.__validate_declare__(class_hash), starknet::VALIDATED);
    assert_eq!(deployable.__validate_deploy__(class_hash, SALT, public_key()), starknet::VALIDATED);
}

#[test]
#[should_panic(expected: 'Account: invalid signature')]
fn test_hint_validate_rejects_invalid_signature() {
    let (address, _) = deploy_account("Falcon512ShakeAccount");
    setup_transaction(address, msg() + 1, signature(), MIN_TRANSACTION_VERSION);
    ISRC6Dispatcher { contract_address: address }.__validate__(array![]);
}

#[test]
#[should_panic(expected: 'Account: invalid signature')]
fn test_direct_validate_rejects_invalid_signature() {
    let (address, _) = deploy_account("Falcon512ShakeDirectAccount");
    setup_transaction(address, msg() + 1, direct_signature(), MIN_TRANSACTION_VERSION);
    ISRC6Dispatcher { contract_address: address }.__validate__(array![]);
}

#[test]
#[should_panic(expected: 'Account: invalid signature')]
fn test_validate_declare_rejects_invalid_signature() {
    let (address, class_hash) = deploy_account("Falcon512ShakeAccount");
    setup_transaction(address, msg() + 1, signature(), MIN_TRANSACTION_VERSION);
    IDeclarerDispatcher { contract_address: address }.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: 'Account: invalid signature')]
fn test_validate_deploy_rejects_invalid_signature() {
    let (address, class_hash) = deploy_account("Falcon512ShakeAccount");
    setup_transaction(address, msg() + 1, signature(), MIN_TRANSACTION_VERSION);
    IFeltArrayDeployableDispatcher { contract_address: address }
        .__validate_deploy__(class_hash, SALT, public_key());
}

#[test]
#[should_panic]
fn test_constructor_rejects_wrong_public_key_length() {
    let contract_class = utils::declare_class("Falcon512ShakeAccount");
    let mut calldata = array![];
    copy_prefix(public_key().span(), PUBLIC_KEY_FELTS - 1).serialize(ref calldata);
    utils::deploy(contract_class, calldata);
}

#[test]
#[should_panic]
fn test_constructor_rejects_noncanonical_public_key() {
    let contract_class = utils::declare_class("Falcon512ShakeDirectAccount");
    let mut calldata = array![];
    with_replaced(public_key().span(), 0, Q_POW_9).serialize(ref calldata);
    utils::deploy(contract_class, calldata);
}

#[test]
fn test_execute_empty_single_multicall_and_supported_versions() {
    let (address, _) = deploy_account("Falcon512ShakeAccount");
    setup_transaction(address, msg(), signature(), MIN_TRANSACTION_VERSION);
    let account = ISRC6Dispatcher { contract_address: address };
    account.__execute__(array![]);

    let target = utils::declare_and_deploy("SimpleMock", array![]);
    let simple = ISimpleMockDispatcher { contract_address: target };
    execute_increase(account, target, 1, MIN_TRANSACTION_VERSION);
    execute_increase(account, target, 2, MIN_TRANSACTION_VERSION + 1);
    execute_increase(account, target, 4, QUERY_VERSION);
    execute_increase(account, target, 8, QUERY_VERSION + 1);

    start_cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    let calldata_a = array![16];
    let calldata_b = array![32];
    let call_a = Call {
        to: target, selector: selector!("increase_balance"), calldata: calldata_a.span(),
    };
    let call_b = Call {
        to: target, selector: selector!("increase_balance"), calldata: calldata_b.span(),
    };
    account.__execute__(array![call_a, call_b]);
    assert_eq!(simple.get_balance(), 63);
}

#[test]
#[should_panic(expected: 'Account: invalid tx version')]
fn test_execute_rejects_zero_version() {
    let (address, _) = deploy_account("Falcon512ShakeAccount");
    setup_transaction(address, msg(), signature(), MIN_TRANSACTION_VERSION - 1);
    ISRC6Dispatcher { contract_address: address }.__execute__(array![]);
}

#[test]
#[should_panic(expected: 'Account: invalid tx version')]
fn test_execute_rejects_query_offset_without_version() {
    let (address, _) = deploy_account("Falcon512ShakeAccount");
    setup_transaction(address, msg(), signature(), QUERY_OFFSET);
    ISRC6Dispatcher { contract_address: address }.__execute__(array![]);
}

#[test]
#[should_panic(expected: 'Account: invalid caller')]
fn test_execute_rejects_contract_caller() {
    let (address, _) = deploy_account("Falcon512ShakeAccount");
    setup_transaction(address, msg(), signature(), MIN_TRANSACTION_VERSION);
    start_cheat_caller_address(address, CALLER);
    ISRC6Dispatcher { contract_address: address }.__execute__(array![]);
}
