use core::num::traits::Zero;
use openzeppelin_interfaces::accounts::{
    FeltArrayAccountABIDispatcher, FeltArrayAccountABIDispatcherTrait, IDeclarerDispatcher,
    IDeclarerDispatcherTrait, IFeltArrayDeployableDispatcher, IFeltArrayDeployableDispatcherTrait,
    IFeltArrayPublicKeyDispatcher, IFeltArrayPublicKeyDispatcherTrait, ISRC6Dispatcher,
    ISRC6DispatcherTrait, ISRC6_ID,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use openzeppelin_test_common::mocks::simple::{ISimpleMockDispatcher, ISimpleMockDispatcherTrait};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{
    CALLER, MIN_TRANSACTION_VERSION, QUERY_OFFSET, QUERY_VERSION, SALT, ZERO,
};
use openzeppelin_testing::{EventSpyExt, ExpectedEvent, spy_events};
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_caller_address, start_cheat_signature_global,
    start_cheat_transaction_hash_global, start_cheat_transaction_version_global,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use starknet::account::Call;
use crate::falcon_512::{
    DIRECT_SIGNATURE_FELTS, Falcon512ShakeDirectVerifier, Falcon512ShakeVerifier, PUBLIC_KEY_FELTS,
    SIGNATURE_FELTS,
};
use super::falcon_512_fixture::{msg, public_key, signature};
use super::falcon_512_rotation_fixture::{
    accept_ownership_hash, accept_ownership_signature, account_address, current_owner_guid,
    new_owner_guid, new_public_key, second_accept_ownership_signature,
};

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

fn direct_accept_ownership_signature() -> Array<felt252> {
    copy_prefix(accept_ownership_signature().span(), DIRECT_SIGNATURE_FELTS)
}

fn deploy_account(contract_name: ByteArray) -> (ContractAddress, felt252) {
    let contract_class = utils::declare_class(contract_name);
    let mut calldata = array![];
    public_key().serialize(ref calldata);
    let contract_address = utils::deploy(contract_class, calldata);
    (contract_address, contract_class.class_hash.into())
}

fn deploy_account_at(
    contract_name: ByteArray, contract_address: ContractAddress,
) -> FeltArrayAccountABIDispatcher {
    let contract_class = utils::declare_class(contract_name);
    let mut calldata = array![];
    public_key().serialize(ref calldata);
    utils::deploy_at(contract_class, contract_address, calldata);
    FeltArrayAccountABIDispatcher { contract_address }
}

fn execute_key_rotation(
    account: FeltArrayAccountABIDispatcher,
    new_key: Array<felt252>,
    acceptance_signature: Array<felt252>,
    setter_selector: felt252,
) {
    let mut calldata = array![];
    new_key.serialize(ref calldata);
    acceptance_signature.serialize(ref calldata);
    account
        .__execute__(
            array![
                Call {
                    to: account.contract_address,
                    selector: setter_selector,
                    calldata: calldata.span(),
                },
            ],
        );
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
fn test_hint_account_rotates_key_via_authenticated_execute() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeAccount", address);
    setup_transaction(address, msg(), signature(), MIN_TRANSACTION_VERSION);

    // Protocol validation authenticates the outer invoke with the current owner.
    assert_eq!(account.__validate__(array![]), starknet::VALIDATED);
    stop_cheat_caller_address(address);
    // Cheat only the outer entrypoint call. The nested self-call keeps its real caller.
    cheat_caller_address(address, ZERO, CheatSpan::TargetCalls(1));

    let mut spy = spy_events();
    execute_key_rotation(
        account, new_public_key(), accept_ownership_signature(), selector!("set_public_key"),
    );

    spy
        .assert_emitted_single(
            address, ExpectedEvent::new().key(selector!("OwnerRemoved")).key(current_owner_guid()),
        );
    spy
        .assert_only_event(
            address, ExpectedEvent::new().key(selector!("OwnerAdded")).key(new_owner_guid()),
        );

    let account = FeltArrayAccountABIDispatcher { contract_address: address };
    assert_eq!(account.get_public_key().span(), new_public_key().span());
    assert_eq!(account.getPublicKey().span(), new_public_key().span());
}

#[test]
fn test_hint_rotated_key_accepts_new_owner_and_rejects_old_owner() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeAccount", address);
    let acceptance_signature = accept_ownership_signature();
    start_cheat_caller_address(address, address);
    account.set_public_key(new_public_key(), acceptance_signature.span());

    assert_eq!(
        account.is_valid_signature(accept_ownership_hash(), accept_ownership_signature()),
        starknet::VALIDATED,
    );
    assert!(account.is_valid_signature(msg(), signature()).is_zero());
}

#[test]
fn test_repeated_key_rotation_keeps_exact_storage_length() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeAccount", address);
    start_cheat_caller_address(address, address);
    let first_signature = accept_ownership_signature();
    account.set_public_key(new_public_key(), first_signature.span());

    // A second rotation overwrites the 29 stored felts instead of growing the Vec.
    let second_signature = second_accept_ownership_signature();
    account.set_public_key(new_public_key(), second_signature.span());
    assert_eq!(account.get_public_key().len(), PUBLIC_KEY_FELTS);
}

#[test]
fn test_direct_account_rotates_key_through_camel_case_abi() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeDirectAccount", address);
    let acceptance_signature = direct_accept_ownership_signature();
    start_cheat_caller_address(address, address);

    let mut spy = spy_events();
    account.setPublicKey(new_public_key(), acceptance_signature.span());

    spy
        .assert_emitted_single(
            address, ExpectedEvent::new().key(selector!("OwnerRemoved")).key(current_owner_guid()),
        );
    spy
        .assert_only_event(
            address, ExpectedEvent::new().key(selector!("OwnerAdded")).key(new_owner_guid()),
        );

    assert_eq!(account.getPublicKey().span(), new_public_key().span());
    assert_eq!(account.get_public_key().span(), new_public_key().span());
}

#[test]
fn test_direct_account_camel_case_signature_alias() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeDirectAccount", address);

    assert_eq!(account.isValidSignature(msg(), direct_signature()), starknet::VALIDATED);
}

#[test]
fn test_constructor_emits_owner_added_guid() {
    let address = account_address();
    let mut spy = spy_events();
    deploy_account_at("Falcon512ShakeAccount", address);

    spy
        .assert_only_event(
            address, ExpectedEvent::new().key(selector!("OwnerAdded")).key(current_owner_guid()),
        );
}

#[test]
#[should_panic(expected: 'Account: unauthorized')]
fn test_key_rotation_rejects_non_self_caller() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeAccount", address);
    start_cheat_caller_address(address, CALLER);

    account.set_public_key(new_public_key(), array![].span());
}

#[test]
#[should_panic(expected: 'Account: invalid public key')]
fn test_key_rotation_rejects_malformed_public_key_before_signature() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeDirectAccount", address);
    start_cheat_caller_address(address, address);

    account
        .set_public_key(
            copy_prefix(new_public_key().span(), PUBLIC_KEY_FELTS - 1), array![].span(),
        );
}

#[test]
#[should_panic(expected: 'Account: invalid signature')]
fn test_key_rotation_rejects_invalid_new_owner_proof() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeAccount", address);
    start_cheat_caller_address(address, address);
    let valid_signature = accept_ownership_signature();
    let invalid_signature = with_replaced(valid_signature.span(), 0, *valid_signature.at(0) + 1);

    account.set_public_key(new_public_key(), invalid_signature.span());
}

#[test]
#[should_panic(expected: 'Account: invalid signature')]
fn test_key_rotation_proof_cannot_be_replayed_to_another_account() {
    let address = CALLER;
    let account = deploy_account_at("Falcon512ShakeDirectAccount", address);
    start_cheat_caller_address(address, address);
    let acceptance_signature = direct_accept_ownership_signature();

    account.set_public_key(new_public_key(), acceptance_signature.span());
}

#[test]
#[should_panic(expected: 'Account: invalid signature')]
fn test_key_rotation_proof_cannot_be_replayed_after_rotation() {
    let address = account_address();
    let account = deploy_account_at("Falcon512ShakeDirectAccount", address);
    start_cheat_caller_address(address, address);
    let acceptance_signature = direct_accept_ownership_signature();

    account.set_public_key(new_public_key(), acceptance_signature.span());
    // The current-owner GUID changed, so the first acceptance proof is no longer valid.
    account.set_public_key(new_public_key(), acceptance_signature.span());
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
