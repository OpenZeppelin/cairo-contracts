use openzeppelin_account::extensions::SRC9Component::SNIP12MetadataImpl;
use openzeppelin_account::extensions::src9::snip12_utils::OutsideExecutionStructHash;
use openzeppelin_interfaces::accounts::{
    FeltArrayAccountABIDispatcher, FeltArrayAccountABIDispatcherTrait, ISRC6_ID,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use openzeppelin_interfaces::src9::{
    ISRC9_V2Dispatcher, ISRC9_V2DispatcherTrait, ISRC9_V2_ID, OutsideExecution,
};
use openzeppelin_interfaces::upgrades::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use openzeppelin_test_common::falcon_512::fixture::{msg, public_key, signature};
use openzeppelin_test_common::falcon_512::rotation_fixture::{
    accept_ownership_hash, accept_ownership_signature, account_address, new_public_key,
    outside_execution_hash, outside_execution_signature,
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::CLASS_HASH_ZERO;
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use snforge_std::{
    start_cheat_block_timestamp_global, start_cheat_caller_address, start_cheat_chain_id_global,
};
use starknet::ContractAddress;

const DIRECT_SIGNATURE_FELTS: u32 = 31;

fn copy_prefix(mut values: Span<felt252>, length: u32) -> Array<felt252> {
    let mut output = array![];
    let mut index = 0;
    while index != length {
        output.append(*values.pop_front().unwrap());
        index += 1;
    }
    output
}

fn direct_signature() -> Array<felt252> {
    copy_prefix(signature().span(), DIRECT_SIGNATURE_FELTS)
}

fn direct_accept_ownership_signature() -> Array<felt252> {
    copy_prefix(accept_ownership_signature().span(), DIRECT_SIGNATURE_FELTS)
}

fn deploy(class_name: ByteArray) -> FeltArrayAccountABIDispatcher {
    let mut calldata = array![];
    public_key().serialize(ref calldata);
    let contract_address = utils::declare_and_deploy(class_name, calldata);
    FeltArrayAccountABIDispatcher { contract_address }
}

fn deploy_at(
    class_name: ByteArray, contract_address: ContractAddress,
) -> FeltArrayAccountABIDispatcher {
    let contract_class = utils::declare_class(class_name);
    let mut calldata = array![];
    public_key().serialize(ref calldata);
    utils::deploy_at(contract_class, contract_address, calldata);
    FeltArrayAccountABIDispatcher { contract_address }
}

fn deploy_with_new_key_at(class_name: ByteArray) -> FeltArrayAccountABIDispatcher {
    let contract_class = utils::declare_class(class_name);
    let mut calldata = array![];
    new_public_key().serialize(ref calldata);
    let contract_address = account_address();
    utils::deploy_at(contract_class, contract_address, calldata);
    FeltArrayAccountABIDispatcher { contract_address }
}

fn assert_constructor_interfaces_and_signature(
    class_name: ByteArray, valid_signature: Array<felt252>,
) {
    let account = deploy(class_name);
    assert_eq!(account.get_public_key().span(), public_key().span());
    assert_eq!(account.is_valid_signature(msg(), valid_signature), starknet::VALIDATED);

    let src5 = ISRC5Dispatcher { contract_address: account.contract_address };
    assert!(src5.supports_interface(ISRC5_ID));
    assert!(src5.supports_interface(ISRC6_ID));
    assert!(src5.supports_interface(ISRC9_V2_ID));
}

#[test]
fn test_falcon_presets_initialize_interfaces_and_variant_verifiers() {
    assert_constructor_interfaces_and_signature("Falcon512ShakeAccountUpgradeable", signature());
    assert_constructor_interfaces_and_signature(
        "Falcon512ShakeDirectAccountUpgradeable", direct_signature(),
    );
}

fn assert_src9_with_real_signature(class_name: ByteArray, valid_signature: Array<felt252>) {
    let account = deploy_with_new_key_at(class_name);
    let src9 = ISRC9_V2Dispatcher { contract_address: account.contract_address };
    let nonce = 5;
    let calls = array![];
    let outside_execution = OutsideExecution {
        caller: 'ANY_CALLER'.try_into().unwrap(),
        nonce,
        execute_after: 10,
        execute_before: 20,
        calls: calls.span(),
    };

    start_cheat_chain_id_global('SN_SEPOLIA');
    assert_eq!(
        outside_execution.get_message_hash(account.contract_address), outside_execution_hash(),
    );
    start_cheat_block_timestamp_global(15);

    assert!(src9.is_valid_outside_execution_nonce(nonce));
    src9.execute_from_outside_v2(outside_execution, valid_signature.span());
    assert!(!src9.is_valid_outside_execution_nonce(nonce));
}

#[test]
fn test_falcon_shake_preset_executes_from_outside_with_real_signature() {
    assert_src9_with_real_signature(
        "Falcon512ShakeAccountUpgradeable", outside_execution_signature(),
    );
}

#[test]
fn test_falcon_shake_direct_preset_executes_from_outside_with_real_signature() {
    assert_src9_with_real_signature(
        "Falcon512ShakeDirectAccountUpgradeable",
        copy_prefix(outside_execution_signature().span(), DIRECT_SIGNATURE_FELTS),
    );
}

fn execute_src9_with_invalid_signature(class_name: ByteArray) {
    let account = deploy(class_name);
    let src9 = ISRC9_V2Dispatcher { contract_address: account.contract_address };
    let outside_execution = OutsideExecution {
        caller: 'ANY_CALLER'.try_into().unwrap(),
        nonce: 5,
        execute_after: 10,
        execute_before: 20,
        calls: array![].span(),
    };

    start_cheat_block_timestamp_global(15);
    src9.execute_from_outside_v2(outside_execution, array![].span());
}

#[test]
#[should_panic(expected: 'SRC9: invalid signature')]
fn test_falcon_shake_preset_routes_src9_signature_validation() {
    execute_src9_with_invalid_signature("Falcon512ShakeAccountUpgradeable");
}

#[test]
#[should_panic(expected: 'SRC9: invalid signature')]
fn test_falcon_shake_direct_preset_routes_src9_signature_validation() {
    execute_src9_with_invalid_signature("Falcon512ShakeDirectAccountUpgradeable");
}

fn reject_unauthorized_upgrade(class_name: ByteArray) {
    let account = deploy(class_name);
    IUpgradeableDispatcher { contract_address: account.contract_address }.upgrade(CLASS_HASH_ZERO);
}

#[test]
#[should_panic(expected: 'Falcon512: unauthorized')]
fn test_falcon_shake_preset_rejects_unauthorized_upgrade() {
    reject_unauthorized_upgrade("Falcon512ShakeAccountUpgradeable");
}

#[test]
#[should_panic(expected: 'Falcon512: unauthorized')]
fn test_falcon_shake_direct_preset_rejects_unauthorized_upgrade() {
    reject_unauthorized_upgrade("Falcon512ShakeDirectAccountUpgradeable");
}

fn assert_rotation_survives_cross_variant_upgrade(
    source_class_name: ByteArray,
    target_class_name: ByteArray,
    rotation_signature: Array<felt252>,
    post_upgrade_signature: Array<felt252>,
) {
    let address = account_address();
    let account = deploy_at(source_class_name, address);
    start_cheat_caller_address(address, address);
    account.set_public_key(new_public_key(), rotation_signature.span());

    let target_class_hash = utils::declare_class(target_class_name).class_hash;
    IUpgradeableDispatcher { contract_address: address }.upgrade(target_class_hash);

    assert_eq!(account.get_public_key().span(), new_public_key().span());
    assert_eq!(
        account.is_valid_signature(accept_ownership_hash(), post_upgrade_signature),
        starknet::VALIDATED,
    );
}

#[test]
fn test_falcon_shake_preset_storage_survives_upgrade_to_direct_variant() {
    assert_rotation_survives_cross_variant_upgrade(
        "Falcon512ShakeAccountUpgradeable",
        "Falcon512ShakeDirectAccountUpgradeable",
        accept_ownership_signature(),
        direct_accept_ownership_signature(),
    );
}

#[test]
fn test_falcon_shake_direct_preset_storage_survives_upgrade_to_hint_variant() {
    assert_rotation_survives_cross_variant_upgrade(
        "Falcon512ShakeDirectAccountUpgradeable",
        "Falcon512ShakeAccountUpgradeable",
        direct_accept_ownership_signature(),
        accept_ownership_signature(),
    );
}
