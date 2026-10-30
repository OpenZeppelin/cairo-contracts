use openzeppelin_account::extensions::SRC9Component::SNIP12MetadataImpl;
use openzeppelin_account::extensions::src9::snip12_utils::OutsideExecutionStructHash;
use openzeppelin_interfaces::accounts::ISRC6_ID;
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_interfaces::src9::{
    ISRC9_V2SafeDispatcher, ISRC9_V2SafeDispatcherTrait, ISRC9_V2_ID, OutsideExecution,
};
use openzeppelin_test_common::multisig_account::get_multisig_signature;
use openzeppelin_test_common::upgrades::UpgradeableSpyHelpers;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::stark::{KEY_PAIR, KEY_PAIR_2};
use openzeppelin_testing::constants::{
    CLASS_HASH_ZERO, FELT_VALUE, MIN_TRANSACTION_VERSION, SALT, TRANSACTION_HASH, ZERO,
};
use openzeppelin_testing::signing::{SerializedSigning, get_stark_keys_from};
use openzeppelin_testing::spy_events;
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use snforge_std::{
    CheatSpan, cheat_caller_address, load, start_cheat_block_timestamp_global,
    start_cheat_signature_global, start_cheat_transaction_hash_global,
    start_cheat_transaction_version_global,
};
use starknet::account::Call;
use starknet::{ClassHash, ContractAddress};
use crate::interfaces::{
    AccountUpgradeableABIDispatcher, AccountUpgradeableABIDispatcherTrait,
    MultisigAccountUpgradeableABIDispatcher, MultisigAccountUpgradeableABIDispatcherTrait,
};

//
// Setup
//

fn signer_public_keys() -> Array<felt252> {
    array![KEY_PAIR().public_key, KEY_PAIR_2().public_key]
}

fn multisig_signature(hash: felt252) -> Array<felt252> {
    get_multisig_signature(hash, array![KEY_PAIR(), KEY_PAIR_2()].span())
}

fn setup_dispatcher() -> (ContractAddress, MultisigAccountUpgradeableABIDispatcher) {
    let signers = signer_public_keys();
    let calldata = array![2, 2, *signers.at(0), *signers.at(1)];
    let account_address = utils::declare_and_deploy("MultisigAccountUpgradeable", calldata);
    let dispatcher = MultisigAccountUpgradeableABIDispatcher { contract_address: account_address };
    (account_address, dispatcher)
}

fn setup_simple_mock() -> ContractAddress {
    utils::declare_and_deploy("SimpleMock", array![])
}

fn multisig_account_mock_class() -> ClassHash {
    utils::declare_class("MultisigAccountMock").class_hash
}

//
// constructor
//

#[test]
fn test_constructor() {
    let (_, dispatcher) = setup_dispatcher();
    let expected_signers = signer_public_keys();

    assert_eq!(dispatcher.get_quorum(), 2);
    assert_eq!(dispatcher.get_signers(), expected_signers.span());
    assert!(dispatcher.is_signer(*expected_signers.at(0)));
    assert!(dispatcher.is_signer(*expected_signers.at(1)));
    assert!(dispatcher.supports_interface(ISRC5_ID));
    assert!(dispatcher.supports_interface(ISRC6_ID));
    assert!(dispatcher.supports_interface(ISRC9_V2_ID));
}

//
// account validation and execution
//

#[test]
fn test_is_valid_signature_and_camel_case() {
    let (_, dispatcher) = setup_dispatcher();
    let hash = 'MULTISIG_HASH';

    assert_eq!(dispatcher.is_valid_signature(hash, multisig_signature(hash)), starknet::VALIDATED);
    assert_eq!(dispatcher.isValidSignature(hash, multisig_signature(hash)), starknet::VALIDATED);
}

#[test]
fn test_execute_self_call_changes_quorum() {
    let (account_address, dispatcher) = setup_dispatcher();
    let call = Call {
        to: account_address, selector: selector!("change_quorum"), calldata: array![1].span(),
    };
    let transaction_hash = 'SELF_CALL_TRANSACTION';
    let signature = multisig_signature(transaction_hash);

    start_cheat_signature_global(signature.span());
    start_cheat_transaction_hash_global(transaction_hash);
    assert_eq!(dispatcher.__validate__(array![call]), starknet::VALIDATED);

    start_cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    cheat_caller_address(account_address, ZERO, CheatSpan::TargetCalls(1));
    dispatcher.__execute__(array![call]);

    assert_eq!(dispatcher.get_quorum(), 1);
}

#[test]
fn test_validate_declare_and_deploy_through_preset() {
    let (_, dispatcher) = setup_dispatcher();
    let class_hash: felt252 = multisig_account_mock_class().into();
    let signers = signer_public_keys();
    start_cheat_signature_global(multisig_signature(TRANSACTION_HASH).span());
    start_cheat_transaction_hash_global(TRANSACTION_HASH);

    assert_eq!(dispatcher.__validate_declare__(class_hash), starknet::VALIDATED);
    assert_eq!(
        dispatcher.__validate_deploy__(class_hash, SALT, 2, signers.span()), starknet::VALIDATED,
    );
}

#[test]
#[should_panic(expected: 'MultisigAcc: unauthorized')]
fn test_change_quorum_rejects_foreign_caller() {
    let (_, dispatcher) = setup_dispatcher();
    dispatcher.change_quorum(1);
}

//
// upgrade
//

#[test]
#[should_panic(expected: 'MultisigAcc: unauthorized')]
fn test_upgrade_access_control() {
    let (_, dispatcher) = setup_dispatcher();
    dispatcher.upgrade(CLASS_HASH_ZERO);
}

#[test]
#[should_panic(expected: 'Class hash cannot be zero')]
fn test_upgrade_with_zero_class_hash() {
    let (account_address, dispatcher) = setup_dispatcher();
    cheat_caller_address(account_address, account_address, CheatSpan::TargetCalls(1));
    dispatcher.upgrade(CLASS_HASH_ZERO);
}

#[test]
fn test_upgrade_preserves_multisig_state() {
    let (account_address, dispatcher) = setup_dispatcher();
    let expected_signers = signer_public_keys();
    let new_class_hash = multisig_account_mock_class();
    let mut spy = spy_events();

    cheat_caller_address(account_address, account_address, CheatSpan::TargetCalls(1));
    dispatcher.upgrade(new_class_hash);

    spy.assert_only_event_upgraded(account_address, new_class_hash);
    assert_eq!(dispatcher.get_quorum(), 2);
    assert_eq!(dispatcher.get_signers(), expected_signers.span());
}

//
// execute_from_outside_v2
//

#[test]
fn test_execute_from_outside_v2_with_multisig_signature() {
    let (account_address, dispatcher) = setup_dispatcher();
    let simple_mock = setup_simple_mock();
    let call = Call {
        to: simple_mock,
        selector: selector!("set_balance"),
        calldata: array![FELT_VALUE, false.into()].span(),
    };
    let outside_execution = OutsideExecution {
        caller: 'ANY_CALLER'.try_into().unwrap(),
        nonce: 5,
        execute_after: 10,
        execute_before: 20,
        calls: array![call].span(),
    };
    start_cheat_block_timestamp_global(15);
    assert!(dispatcher.is_valid_outside_execution_nonce(outside_execution.nonce));

    let hash = outside_execution.get_message_hash(account_address);
    let signature = multisig_signature(hash);
    dispatcher.execute_from_outside_v2(outside_execution, signature.span());

    assert!(!dispatcher.is_valid_outside_execution_nonce(5));
    let value = *load(simple_mock, selector!("balance"), 1).at(0);
    assert_eq!(value, FELT_VALUE);
}

fn outside_execution_with(call: Call, nonce: felt252) -> OutsideExecution {
    OutsideExecution {
        caller: 'ANY_CALLER'.try_into().unwrap(),
        nonce,
        execute_after: 10,
        execute_before: 20,
        calls: array![call].span(),
    }
}

fn set_balance_call(simple_mock: ContractAddress) -> Call {
    Call {
        to: simple_mock,
        selector: selector!("set_balance"),
        calldata: array![FELT_VALUE, false.into()].span(),
    }
}

#[test]
#[should_panic(expected: 'SRC9: invalid signature')]
fn test_execute_from_outside_v2_rejects_sub_quorum_signature() {
    let (account_address, dispatcher) = setup_dispatcher();
    let outside_execution = outside_execution_with(set_balance_call(setup_simple_mock()), 5);
    start_cheat_block_timestamp_global(15);

    let hash = outside_execution.get_message_hash(account_address);
    let signature = get_multisig_signature(hash, array![KEY_PAIR()].span());
    dispatcher.execute_from_outside_v2(outside_execution, signature.span());
}

#[test]
#[should_panic(expected: 'SRC9: invalid signature')]
fn test_execute_from_outside_v2_rejects_bundle_for_other_hash() {
    let (_, dispatcher) = setup_dispatcher();
    let outside_execution = outside_execution_with(set_balance_call(setup_simple_mock()), 5);
    start_cheat_block_timestamp_global(15);

    let signature = multisig_signature('OTHER_HASH');
    dispatcher.execute_from_outside_v2(outside_execution, signature.span());
}

#[test]
#[feature("safe_dispatcher")]
fn test_execute_from_outside_v2_cancels_pending_execution_with_same_nonce() {
    let (account_address, dispatcher) = setup_dispatcher();
    let safe_src9 = ISRC9_V2SafeDispatcher { contract_address: account_address };
    let simple_mock = setup_simple_mock();
    let pending = outside_execution_with(set_balance_call(simple_mock), 5);
    let pending_signature = multisig_signature(pending.get_message_hash(account_address));
    let cancellation = OutsideExecution { calls: array![].span(), ..pending };
    let cancellation_signature = multisig_signature(cancellation.get_message_hash(account_address));
    start_cheat_block_timestamp_global(15);

    let result = dispatcher.execute_from_outside_v2(cancellation, cancellation_signature.span());
    assert!(result.is_empty());
    assert!(!dispatcher.is_valid_outside_execution_nonce(pending.nonce));

    let error = safe_src9.execute_from_outside_v2(pending, pending_signature.span()).unwrap_err();
    assert_eq!(*error.at(0), 'SRC9: duplicated nonce');
    assert_eq!(*load(simple_mock, selector!("balance"), 1).at(0), 0);
}

#[test]
#[feature("safe_dispatcher")]
fn test_execute_from_outside_v2_invalid_cancellation_preserves_nonce() {
    let (account_address, dispatcher) = setup_dispatcher();
    let safe_src9 = ISRC9_V2SafeDispatcher { contract_address: account_address };
    let simple_mock = setup_simple_mock();
    let pending = outside_execution_with(set_balance_call(simple_mock), 5);
    let pending_signature = multisig_signature(pending.get_message_hash(account_address));
    let cancellation = OutsideExecution { calls: array![].span(), ..pending };
    start_cheat_block_timestamp_global(15);

    // Authorizing the pending calls does not authorize an empty replacement. Failed
    // verification must roll back the nonce write so the pending execution can still run.
    let error = safe_src9
        .execute_from_outside_v2(cancellation, pending_signature.span())
        .unwrap_err();
    assert_eq!(*error.at(0), 'SRC9: invalid signature');
    assert!(dispatcher.is_valid_outside_execution_nonce(pending.nonce));

    dispatcher.execute_from_outside_v2(pending, pending_signature.span());
    assert!(!dispatcher.is_valid_outside_execution_nonce(pending.nonce));
    assert_eq!(*load(simple_mock, selector!("balance"), 1).at(0), FELT_VALUE);
}

#[test]
fn test_execute_from_outside_v2_self_call_updates_configuration() {
    let (account_address, dispatcher) = setup_dispatcher();
    let new_signer = get_stark_keys_from('PRIVATE_KEY_3').public_key;
    // Outside execution is the recovery path: the quorum adds a signer and lowers itself.
    let add_signers_call = Call {
        to: account_address,
        selector: selector!("add_signers"),
        calldata: array![1, 1, new_signer].span(),
    };
    let outside_execution = outside_execution_with(add_signers_call, 7);
    start_cheat_block_timestamp_global(15);

    let hash = outside_execution.get_message_hash(account_address);
    dispatcher.execute_from_outside_v2(outside_execution, multisig_signature(hash).span());

    assert_eq!(dispatcher.get_quorum(), 1);
    assert!(dispatcher.is_signer(new_signer));
    assert!(!dispatcher.is_valid_outside_execution_nonce(7));
}

//
// migration from AccountUpgradeable
//

fn migrate_from_account_upgradeable() -> ContractAddress {
    let owner = get_stark_keys_from('LEGACY_OWNER');
    let account_address = utils::declare_and_deploy("AccountUpgradeable", array![owner.public_key]);
    let legacy = AccountUpgradeableABIDispatcher { contract_address: account_address };
    let multisig_class = utils::declare_class("MultisigAccountUpgradeable").class_hash;
    let signers = signer_public_keys();

    // An upgrade alone leaves the quorum at zero with no way to authorize a fix, so the class
    // replacement and the signer setup run in one multicall. The second call already executes
    // on the new class.
    let upgrade_call = Call {
        to: account_address,
        selector: selector!("upgrade"),
        calldata: array![multisig_class.into()].span(),
    };
    let setup_call = Call {
        to: account_address,
        selector: selector!("add_signers"),
        calldata: array![2, 2, *signers.at(0), *signers.at(1)].span(),
    };
    start_cheat_signature_global(owner.serialized_sign(TRANSACTION_HASH).span());
    start_cheat_transaction_hash_global(TRANSACTION_HASH);
    assert_eq!(legacy.__validate__(array![upgrade_call, setup_call]), starknet::VALIDATED);
    start_cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    cheat_caller_address(account_address, ZERO, CheatSpan::TargetCalls(1));
    legacy.__execute__(array![upgrade_call, setup_call]);
    account_address
}

#[test]
fn test_migration_from_account_upgradeable_in_one_multicall() {
    let account_address = migrate_from_account_upgradeable();
    let signers = signer_public_keys();
    let migrated = MultisigAccountUpgradeableABIDispatcher { contract_address: account_address };
    assert_eq!(migrated.get_quorum(), 2);
    assert_eq!(migrated.get_signers(), signers.span());
    let hash = 'MIGRATED_HASH';
    assert_eq!(migrated.is_valid_signature(hash, multisig_signature(hash)), starknet::VALIDATED);
    // Interface registrations carry over from the previous class; the new constructor never runs.
    assert!(migrated.supports_interface(ISRC6_ID));
    assert!(migrated.supports_interface(ISRC9_V2_ID));
}

#[test]
fn test_quorum_authorized_upgrade_back_restores_legacy_owner() {
    let account_address = migrate_from_account_upgradeable();
    let migrated = MultisigAccountUpgradeableABIDispatcher { contract_address: account_address };
    let owner = get_stark_keys_from('LEGACY_OWNER');
    let hash = 'RESTORED_OWNER_HASH';
    let owner_signature = owner.serialized_sign(hash);
    assert!(!migrated.is_signer(owner.public_key));
    assert_eq!(migrated.is_valid_signature(hash, owner_signature.clone()), 0);

    let legacy_class = utils::declare_class("AccountUpgradeable").class_hash;
    let upgrade_call = Call {
        to: account_address,
        selector: selector!("upgrade"),
        calldata: array![legacy_class.into()].span(),
    };
    let outside_execution = outside_execution_with(upgrade_call, 7);
    let upgrade_hash = outside_execution.get_message_hash(account_address);
    start_cheat_block_timestamp_global(15);
    migrated.execute_from_outside_v2(outside_execution, multisig_signature(upgrade_hash).span());

    // The quorum authorized only the class upgrade; the retired owner provided no new
    // acceptance signature. Its stored public key becomes authoritative again.
    let restored = AccountUpgradeableABIDispatcher { contract_address: account_address };
    assert_eq!(restored.get_public_key(), owner.public_key);
    assert_eq!(restored.is_valid_signature(hash, owner_signature.clone()), starknet::VALIDATED);
    start_cheat_signature_global(owner_signature.span());
    start_cheat_transaction_hash_global(hash);
    assert_eq!(restored.__validate__(array![]), starknet::VALIDATED);
}
