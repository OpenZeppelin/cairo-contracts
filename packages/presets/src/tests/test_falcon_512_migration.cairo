use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::{PoseidonTrait, poseidon_hash_span};
use openzeppelin_account::extensions::SRC9Component::SNIP12MetadataImpl;
use openzeppelin_account::extensions::src9::snip12_utils::OutsideExecutionStructHash;
use openzeppelin_account::falcon_512::verifier_impls::DIRECT_SIGNATURE_FELTS;
use openzeppelin_interfaces::accounts::{
    IFeltArrayPublicKeyDispatcher, IFeltArrayPublicKeyDispatcherTrait, ISRC6Dispatcher,
    ISRC6DispatcherTrait, ISRC6SafeDispatcher, ISRC6SafeDispatcherTrait, ISRC6_ID,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use openzeppelin_interfaces::src9::{
    ISRC9_V2Dispatcher, ISRC9_V2DispatcherTrait, ISRC9_V2_ID, OutsideExecution,
};
use openzeppelin_test_common::falcon_512::migration_fixture as fixture;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{MIN_TRANSACTION_VERSION, ZERO, secp256k1, stark};
use openzeppelin_testing::events::{EventSpyExt, ExpectedEvent};
use openzeppelin_testing::signing::SerializedSigning;
use openzeppelin_testing::spy_events;
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use snforge_std::{
    CheatSpan, cheat_caller_address, get_class_hash, start_cheat_block_timestamp,
    start_cheat_signature, start_cheat_transaction_hash, start_cheat_transaction_version,
};
use starknet::ClassHash;
use starknet::account::Call;

fn source_signature(is_eth: bool, hash: felt252) -> Array<felt252> {
    if is_eth {
        secp256k1::KEY_PAIR().serialized_sign(hash.into())
    } else {
        stark::KEY_PAIR().serialized_sign(hash)
    }
}

fn deploy_source(is_eth: bool) -> ISRC6Dispatcher {
    let mut calldata = array![];
    let class_name = if is_eth {
        secp256k1::KEY_PAIR().public_key.serialize(ref calldata);
        "EthAccountUpgradeable"
    } else {
        stark::KEY_PAIR().public_key.serialize(ref calldata);
        "AccountUpgradeable"
    };
    let address = fixture::account_address();
    utils::declare_and_deploy_at(class_name, address, calldata);
    start_cheat_transaction_version(address, MIN_TRANSACTION_VERSION);
    start_cheat_transaction_hash(address, fixture::transaction_hash());
    start_cheat_signature(address, source_signature(is_eth, fixture::transaction_hash()).span());
    ISRC6Dispatcher { contract_address: address }
}

fn target_class_hash(direct: bool) -> ClassHash {
    let class_name = if direct {
        "Falcon512ShakeDirectAccountUpgradeable"
    } else {
        "Falcon512ShakeAccountUpgradeable"
    };
    utils::declare_class(class_name).class_hash
}

fn falcon_signature(signature: Array<felt252>, direct: bool) -> Array<felt252> {
    if direct {
        signature.span().slice(0, DIRECT_SIGNATURE_FELTS).into()
    } else {
        signature
    }
}

fn migration_calls(class_hash: ClassHash, proof: Array<felt252>) -> Array<Call> {
    let address = fixture::account_address();
    let mut key_calldata = array![];
    fixture::public_key().serialize(ref key_calldata);
    proof.serialize(ref key_calldata);
    array![
        Call {
            to: address, selector: selector!("upgrade"), calldata: array![class_hash.into()].span(),
        },
        Call { to: address, selector: selector!("set_public_key"), calldata: key_calldata.span() },
    ]
}

fn consume_outside_nonce(account: ISRC6Dispatcher, is_eth: bool) {
    let outside = OutsideExecution {
        caller: 'ANY_CALLER'.try_into().unwrap(),
        nonce: 5,
        execute_after: 10,
        execute_before: 20,
        calls: array![].span(),
    };
    let address = account.contract_address;
    start_cheat_block_timestamp(address, 15);
    let signature = source_signature(is_eth, outside.get_message_hash(address));
    ISRC9_V2Dispatcher { contract_address: address }
        .execute_from_outside_v2(outside, signature.span());
}

fn assert_migration(is_eth: bool, direct: bool) {
    let account = deploy_source(is_eth);
    let address = account.contract_address;
    consume_outside_nonce(account, is_eth);
    let target = target_class_hash(direct);
    let proof = falcon_signature(fixture::accept_ownership_signature(), direct);
    let calls = migration_calls(target, proof);

    // The old key authorizes the transaction; the new key accepts ownership of empty Falcon
    // storage.
    let acceptance_hash = PoseidonTrait::new()
        .update_with('StarkNet Message')
        .update_with('accept_ownership')
        .update_with(address)
        .update_with(poseidon_hash_span(array![].span()))
        .finalize();
    assert_eq!(acceptance_hash, fixture::accept_ownership_hash());
    assert_eq!(account.__validate__(calls.clone()), starknet::VALIDATED);
    let mut spy = spy_events();
    // Only the outer call comes from the protocol; both self-calls use their actual caller.
    cheat_caller_address(address, ZERO, CheatSpan::TargetCalls(1));
    account.__execute__(calls);

    spy
        .assert_emitted_single(
            address, ExpectedEvent::new().key(selector!("Upgraded")).data(target),
        );
    spy
        .assert_emitted_single(
            address,
            ExpectedEvent::new()
                .key(selector!("OwnerRemoved"))
                .key(poseidon_hash_span(array![].span())),
        );
    spy
        .assert_only_event(
            address,
            ExpectedEvent::new()
                .key(selector!("OwnerAdded"))
                .key(poseidon_hash_span(fixture::public_key().span())),
        );
    assert_eq!(get_class_hash(address), target);
    let key = IFeltArrayPublicKeyDispatcher { contract_address: address }.get_public_key();
    assert_eq!(key, fixture::public_key());
    let src5 = ISRC5Dispatcher { contract_address: address };
    assert!(src5.supports_interface(ISRC5_ID));
    assert!(src5.supports_interface(ISRC6_ID));
    assert!(src5.supports_interface(ISRC9_V2_ID));
    let src9 = ISRC9_V2Dispatcher { contract_address: address };
    assert!(!src9.is_valid_outside_execution_nonce(5));
    assert!(src9.is_valid_outside_execution_nonce(6));
    assert_eq!(
        account
            .is_valid_signature(
                fixture::transaction_hash(), source_signature(is_eth, fixture::transaction_hash()),
            ),
        0,
    );

    let signature = falcon_signature(fixture::transaction_signature(), direct);
    start_cheat_signature(address, signature.span());
    assert_eq!(account.__validate__(array![]), starknet::VALIDATED);
    cheat_caller_address(address, ZERO, CheatSpan::TargetCalls(1));
    account.__execute__(array![]);
}

#[feature("safe_dispatcher")]
fn assert_failed_migration_rolls_back(is_eth: bool, direct: bool) {
    let account = deploy_source(is_eth);
    let address = account.contract_address;
    let original_class = get_class_hash(address);
    consume_outside_nonce(account, is_eth);
    // This is a valid signature under the new key, but for a different message.
    let wrong_proof = falcon_signature(fixture::transaction_signature(), direct);
    let calls = migration_calls(target_class_hash(direct), wrong_proof);
    assert_eq!(account.__validate__(calls.clone()), starknet::VALIDATED);
    cheat_caller_address(address, ZERO, CheatSpan::TargetCalls(1));
    let error = ISRC6SafeDispatcher { contract_address: address }.__execute__(calls).unwrap_err();
    assert!(error.span().into_iter().any(|value| *value == 'Falcon512: invalid signature'));

    assert_eq!(get_class_hash(address), original_class);
    assert_eq!(account.__validate__(array![]), starknet::VALIDATED);
    assert!(!ISRC9_V2Dispatcher { contract_address: address }.is_valid_outside_execution_nonce(5));

    // Retrying with acceptance of the empty key proves the failed migration left it uninitialized.
    let proof = falcon_signature(fixture::accept_ownership_signature(), direct);
    let calls = migration_calls(target_class_hash(direct), proof);
    cheat_caller_address(address, ZERO, CheatSpan::TargetCalls(1));
    account.__execute__(calls);
    assert_eq!(
        IFeltArrayPublicKeyDispatcher { contract_address: address }.get_public_key(),
        fixture::public_key(),
    );
}

#[test]
fn test_standard_migration_to_falcon_hint() {
    assert_migration(is_eth: false, direct: false);
}

#[test]
fn test_standard_migration_to_falcon_direct() {
    assert_migration(is_eth: false, direct: true);
}

#[test]
fn test_eth_migration_to_falcon_hint() {
    assert_migration(is_eth: true, direct: false);
}

#[test]
fn test_eth_migration_to_falcon_direct() {
    assert_migration(is_eth: true, direct: true);
}

#[test]
fn test_standard_migration_to_falcon_hint_rolls_back_invalid_proof() {
    assert_failed_migration_rolls_back(is_eth: false, direct: false);
}

#[test]
fn test_standard_migration_to_falcon_direct_rolls_back_invalid_proof() {
    assert_failed_migration_rolls_back(is_eth: false, direct: true);
}

#[test]
fn test_eth_migration_to_falcon_hint_rolls_back_invalid_proof() {
    assert_failed_migration_rolls_back(is_eth: true, direct: false);
}

#[test]
fn test_eth_migration_to_falcon_direct_rolls_back_invalid_proof() {
    assert_failed_migration_rolls_back(is_eth: true, direct: true);
}
