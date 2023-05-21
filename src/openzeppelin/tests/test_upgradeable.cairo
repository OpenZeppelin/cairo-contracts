use openzeppelin::upgrades::upgradeable::Upgradeable;
use openzeppelin::tests::utils;

use openzeppelin::tests::mocks::upgrades_v1::Upgrades_V1;
use openzeppelin::tests::mocks::upgrades_v1::IUpgrades_V1Dispatcher;
use openzeppelin::tests::mocks::upgrades_v1::IUpgrades_V1DispatcherTrait;

use openzeppelin::tests::mocks::upgrades_v2::Upgrades_V2;
use openzeppelin::tests::mocks::upgrades_v2::IUpgrades_V2Dispatcher;
use openzeppelin::tests::mocks::upgrades_v2::IUpgrades_V2DispatcherTrait;

use array::ArrayTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::class_hash::ClassHash;
use starknet::class_hash::class_hash_const;
use starknet::testing;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::class_hash::Felt252TryIntoClassHash;
use traits::TryInto;

const VALUE: felt252 = 123;
const VALUE2: felt252 = 789;
const SET_VALUE_SELECTOR: felt252 =
    0x3d7905601c217734671143d457f0db37f7f8883112abd34b92c4abfeafde0c3;
const SET_VALUE2_SELECTOR: felt252 =
    0x47c8c185eb97d3925831a1c97e43bd9077181d2b200133ede551f1c47056a3;
const REMOVE_SELECTOR: felt252 = 0x2beeaa48bce210364c7d2f2fbb677e08136cb29e8972a6728249364dde19e6f;

fn deploy_mock() -> IUpgrades_V1Dispatcher {
    let calldata = ArrayTrait::new();
    let address = utils::deploy(Upgrades_V1::TEST_CLASS_HASH, calldata);
    IUpgrades_V1Dispatcher { contract_address: address }
}

fn ADMIN() -> ContractAddress {
    contract_address_const::<1>()
}

fn OTHER() -> ContractAddress {
    contract_address_const::<2>()
}

fn CALLDATA(val_n: felt252) -> Array<felt252> {
    let mut arr = ArrayTrait::new();
    arr.append(val_n);
    arr
}

fn V2_CLASS_HASH() -> ClassHash {
    Upgrades_V2::TEST_CLASS_HASH.try_into().unwrap()
}

fn CLASS_HASH_ZERO() -> ClassHash {
    class_hash_const::<0>()
}

// Many of the following tests are ignored because `replace_class_syscall`
// is not yet supported in casm-run.
// See: https://github.com/starkware-libs/cairo/blob/e5c65df312338e4d8e1e0ed46409094bd0caa702/crates/cairo-lang-runner/src/casm_run/mod.rs#L523

//
// Internal
//

#[test]
#[ignore]
#[available_gas(2000000)]
fn test__upgrade() {
    Upgradeable::_upgrade(V2_CLASS_HASH());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Class hash cannot be zero', ))]
fn test__upgrade_with_zero_class_hash() {
    Upgradeable::_upgrade(CLASS_HASH_ZERO());
}

#[test]
#[ignore]
#[available_gas(2000000)]
fn test__upgrade_and_call() {
    Upgradeable::_upgrade_and_call(V2_CLASS_HASH(), SET_VALUE_SELECTOR, CALLDATA(VALUE));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Class hash cannot be zero', ))]
fn test__upgrade_and_call_with_zero_class_hash() {
    Upgradeable::_upgrade_and_call(CLASS_HASH_ZERO(), SET_VALUE_SELECTOR, CALLDATA(VALUE));
}
//
// Mock implementation
//

#[test]
#[ignore]
#[available_gas(2000000)]
fn test_new_selector_after_upgrade() {
    let contract = deploy_mock();

    contract.upgrade(V2_CLASS_HASH());
    let contract_v2 = IUpgrades_V2Dispatcher { contract_address: contract.contract_address };

    contract_v2.set_value2(VALUE);
    assert(contract_v2.get_value2() == VALUE, 'New selector should be callable');
}

#[test]
#[ignore]
#[available_gas(2000000)]
fn test_state_persists_after_upgrade() {
    let contract = deploy_mock();
    contract.set_value(VALUE);

    contract.upgrade(V2_CLASS_HASH());
    let contract_v2 = IUpgrades_V2Dispatcher { contract_address: contract.contract_address };

    assert(contract_v2.get_value() == VALUE, 'Should keep state after upgrade');
}

#[test]
#[available_gas(2000000)]
fn test_remove_selector_passes() {
    let contract = deploy_mock();
    contract.remove_selector();
}

#[test]
#[ignore]
#[available_gas(2000000)]
#[should_panic]
fn test_remove_selector_is_removed_after_upgrade() {
    let contract = deploy_mock();

    contract.upgrade(V2_CLASS_HASH());
    let contract_v2 = IUpgrades_V2Dispatcher { contract_address: contract.contract_address };
// Compiler error because remove_selector is not part of the v2 interface
//contract_v2.remove_selector();
}

#[test]
#[ignore]
#[available_gas(2000000)]
fn test_upgrade_and_call_executes_call() {
    let contract = deploy_mock();

    // Calls set_value that exists in both V1 and V2
    contract.upgrade_and_call(V2_CLASS_HASH(), SET_VALUE_SELECTOR, CALLDATA(VALUE));
    let contract_v2 = IUpgrades_V2Dispatcher { contract_address: contract.contract_address };

    assert(contract_v2.get_value() == VALUE, 'Should set val during upgrade');
}

#[test]
#[ignore]
#[available_gas(2000000)]
fn test_upgrade_and_call_new_selector() {
    let contract = deploy_mock();

    contract.upgrade_and_call(V2_CLASS_HASH(), SET_VALUE2_SELECTOR, CALLDATA(VALUE2));
    let contract_v2 = IUpgrades_V2Dispatcher { contract_address: contract.contract_address };

    assert(contract_v2.get_value2() == VALUE2, 'Should set val during upgrade');
}

#[test]
#[ignore]
#[available_gas(2000000)]
#[should_panic]
fn test_upgrade_and_call_with_removed_selector() {
    let contract = deploy_mock();

    let calldata = ArrayTrait::new();
    contract.upgrade_and_call(V2_CLASS_HASH(), REMOVE_SELECTOR, calldata);
}
