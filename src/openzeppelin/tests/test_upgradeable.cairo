use openzeppelin::tests::mocks::upgrades_v1::Upgrades_V1;
use openzeppelin::tests::mocks::upgrades_v2::Upgrades_V2;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::class_hash::ClassHash;
use starknet::class_hash::class_hash_const;
use starknet::testing::set_caller_address;
use traits::Into;
use zeroable::Zeroable;

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn ADMIN() -> ContractAddress {
    contract_address_const::<1>()
}

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    //let hash_1: ClassHash = class_hash_const::<10>();
    assert(Upgrades_V1::get_admin() == ZERO(), '');
    Upgrades_V1::constructor(ADMIN());
    assert(Upgrades_V1::get_admin() == ADMIN(), '');
}

#[test]
#[available_gas(2000000)]
fn test_upgrade() {
    Upgrades_V1::constructor(ADMIN());
    let new_class_hash: ClassHash = class_hash_const::<99>();
    set_caller_address(ADMIN());
    Upgrades_V1::upgrade(new_class_hash);
}

