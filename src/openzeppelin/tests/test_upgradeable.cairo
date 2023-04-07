use openzeppelin::upgrades::upgradeable::Upgradeable;
use openzeppelin::tests::mocks::upgrades_v1::Upgrades_V1;
use openzeppelin::tests::mocks::upgrades_v2::Upgrades_V2;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::class_hash::ClassHash;
use starknet::class_hash::class_hash_const;
use starknet::testing::set_caller_address;

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn ADMIN() -> ContractAddress {
    contract_address_const::<1>()
}

fn OTHER() -> ContractAddress {
    contract_address_const::<2>()
}

//
// Setup functions
//

fn setup() {
    Upgradeable::initializer(ADMIN());
    set_caller_address(ADMIN());
}

fn setup_impl() {
    Upgrades_V1::constructor(ADMIN());
    set_caller_address(ADMIN());
}

//
// Internal
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    assert(Upgradeable::get_admin() == ZERO(), '');
    Upgradeable::initializer(ADMIN());
    assert(Upgradeable::get_admin() == ADMIN(), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Contract already initialized', ))]
fn test_initialize_twice() {
    Upgradeable::initializer(ADMIN());
    Upgradeable::initializer(ADMIN());
}

#[test]
#[available_gas(2000000)]
fn test__set_new_admin() {
    setup();
    Upgradeable::_set_admin(OTHER());
    assert(Upgradeable::get_admin() == OTHER(), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Admin cannot be zero', ))]
fn test__set_admin_zero() {
    setup();
    Upgradeable::_set_admin(ZERO());
}

#[test]
#[available_gas(2000000)]
fn test__upgrade() {
    //setup();
    //Upgradeable::_upgrade(class_hash_const::<123456789>());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Class hash cannot be zero', ))]
fn test__upgrade_with_zero_class_hash() {
    setup();
    Upgradeable::_upgrade(class_hash_const::<0>());
}

//
// Mock implementation
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    assert(Upgrades_V1::get_admin() == ZERO(), '');
    Upgrades_V1::constructor(ADMIN());
    assert(Upgrades_V1::get_admin() == ADMIN(), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Admin cannot be zero', ))]
fn test_constructor_with_admin_zero() {
    Upgrades_V1::constructor(ZERO());
}

#[test]
#[available_gas(2000000)]
fn test_set_new_admin() {
    setup_impl();
    Upgrades_V1::set_admin(OTHER());
    assert(Upgrades_V1::get_admin() == OTHER(), '');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Caller is not admin', ))]
fn test_set_new_admin_from_unauthorized() {
    setup_impl();
    set_caller_address(OTHER());
    Upgrades_V1::set_admin(OTHER());
}

#[test]
#[available_gas(2000000)]
fn test_upgrade() {
    //setup_impl();
    //Upgrades_V1::constructor(ADMIN());
    //let new_class_hash: ClassHash = class_hash_const::<123456789>();
    //set_caller_address(ADMIN());
    //Upgrades_V1::upgrade(new_class_hash);
}

#[test]
#[available_gas(2000000)]
fn test_upgrade_from_unauthorized() {
    //setup_impl();
    //let new_class_hash: ClassHash = class_hash_const::<123456789>();
    //set_caller_address(OTHER());
    //Upgrades_V1::upgrade(new_class_hash);
}

