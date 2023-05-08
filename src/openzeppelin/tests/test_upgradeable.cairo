use openzeppelin::upgrades::upgradeable::Upgradeable;
use openzeppelin::tests::mocks::{upgrades_v1::Upgrades_V1, upgrades_v2::Upgrades_V2};
use array::ArrayTrait;
use starknet::{
    class_hash::{
    ClassHash, class_hash_const
    }, testing::set_caller_address, ContractAddress, contract_address_const
};

const VALUE: felt252 = 123;
const NEW_VALUE: felt252 = 456;
const VALUE2: felt252 = 789;
const SELECTOR: felt252 = 'set_value';
const SELECTOR2: felt252 = 'set_value2';
const REMOVED_SELECTOR: felt252 = 'remove_selector';

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

// Mock until tests support declarations
fn MOCK_V2_CLASS_HASH() -> ClassHash {
    class_hash_const::<123456789>()
}

//
// Internal
//

#[test]
#[ignore] // replace_class_syscall() not yet supported in tests
#[available_gas(2000000)]
fn test__upgrade() {
    Upgradeable::_upgrade(MOCK_V2_CLASS_HASH());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Class hash cannot be zero', ))]
fn test__upgrade_with_zero_class_hash() {
    Upgradeable::_upgrade(class_hash_const::<0>());
}

#[test]
#[ignore] // replace_class_syscall() not yet supported in tests
#[available_gas(2000000)]
fn test__upgrade_and_call() {
    Upgradeable::_upgrade_and_call(MOCK_V2_CLASS_HASH(), SELECTOR, CALLDATA(VALUE));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Class hash cannot be zero', ))]
fn test__upgrade_and_call_with_zero_class_hash() {
    Upgradeable::_upgrade_and_call(class_hash_const::<0>(), SELECTOR, CALLDATA(VALUE));
}

//
// Mock implementation
//

#[test]
#[ignore] // replace_class_syscall() not yet supported in tests
#[available_gas(2000000)]
fn test_upgrade() {
    assert(Upgrades_V1::get_value() == 0, 'Value should be zero');
    Upgrades_V1::set_value(VALUE);
    assert(Upgrades_V1::get_value() == VALUE, 'Value should be set');

    Upgrades_V1::upgrade(MOCK_V2_CLASS_HASH());
    assert(Upgrades_V2::get_value() == VALUE, 'Value should be set from V1');

    Upgrades_V2::set_value(NEW_VALUE);
    assert(Upgrades_V2::get_value() == NEW_VALUE, 'New value should be set');
}

#[test]
#[ignore] // replace_class_syscall() not yet supported in tests
#[available_gas(2000000)]
fn test_upgrade_and_call_persisting_selector() {
    assert(Upgrades_V1::get_value() == 0, 'Value should be zero');
    Upgrades_V1::set_value(VALUE);
    assert(Upgrades_V1::get_value() == VALUE, 'Value should be set');

    Upgrades_V1::upgrade_and_call(MOCK_V2_CLASS_HASH(), SELECTOR, CALLDATA(VALUE));
    assert(Upgrades_V2::get_value() == VALUE, 'Value should be set from V1');

    Upgrades_V2::set_value(NEW_VALUE);
    assert(Upgrades_V2::get_value() == NEW_VALUE, 'New value should be set');
}

#[test]
#[ignore] // replace_class_syscall() not yet supported in tests
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_FAILED', ))]
fn test_upgrade_and_call_removed_selector() {
    let mut arr = ArrayTrait::new();
    Upgrades_V1::upgrade_and_call(MOCK_V2_CLASS_HASH(), REMOVED_SELECTOR, arr);
}

#[test]
#[ignore] // replace_class_syscall() not yet supported in tests
#[available_gas(2000000)]
fn test_upgrade_and_call_new_selector() {
    Upgrades_V1::upgrade_and_call(MOCK_V2_CLASS_HASH(), SELECTOR2, CALLDATA(VALUE2));
    assert(Upgrades_V2::get_value2() == VALUE2, 'Value should be set from v1');
}
