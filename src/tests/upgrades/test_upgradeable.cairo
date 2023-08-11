use array::ArrayTrait;
use openzeppelin::tests::mocks::upgrades_v1::IUpgradesV1Dispatcher;
use openzeppelin::tests::mocks::upgrades_v1::IUpgradesV1DispatcherTrait;
use openzeppelin::tests::mocks::upgrades_v2::IUpgradesV2Dispatcher;
use openzeppelin::tests::mocks::upgrades_v2::IUpgradesV2DispatcherTrait;
use openzeppelin::tests::mocks::upgrades_v1::UpgradesV1;
use openzeppelin::tests::mocks::upgrades_v2::UpgradesV2;
use openzeppelin::tests::utils;
use openzeppelin::upgrades::upgradeable::Upgradeable::Upgraded;
use option::OptionTrait;
use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::Felt252TryIntoClassHash;
use starknet::class_hash_const;
use starknet::contract_address_const;
use starknet::testing;
use traits::TryInto;

const VALUE: felt252 = 123;

fn V2_CLASS_HASH() -> ClassHash {
    UpgradesV2::TEST_CLASS_HASH.try_into().unwrap()
}

fn CLASS_HASH_ZERO() -> ClassHash {
    class_hash_const::<0>()
}

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

//
// Setup
//

fn deploy_v1() -> IUpgradesV1Dispatcher {
    let calldata = array![];
    let address = utils::deploy(UpgradesV1::TEST_CLASS_HASH, calldata);
    IUpgradesV1Dispatcher { contract_address: address }
}

//
// upgrade
//

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED', ))]
fn test_upgrade_with_class_hash_zero() {
    let v1 = deploy_v1();
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
#[available_gas(2000000)]
fn test_upgraded_event() {
    let v1 = deploy_v1();
    v1.upgrade(V2_CLASS_HASH());

    let event = testing::pop_log::<Upgraded>(v1.contract_address).unwrap();
    assert(event.class_hash == V2_CLASS_HASH(), 'Invalid class hash');
}

#[test]
#[available_gas(2000000)]
fn test_new_selector_after_upgrade() {
    let v1 = deploy_v1();

    v1.upgrade(V2_CLASS_HASH());
    let v2 = IUpgradesV2Dispatcher { contract_address: v1.contract_address };

    v2.set_value2(VALUE);
    assert(v2.get_value2() == VALUE, 'New selector should be callable');
}

#[test]
#[available_gas(2000000)]
fn test_state_persists_after_upgrade() {
    let v1 = deploy_v1();
    v1.set_value(VALUE);

    v1.upgrade(V2_CLASS_HASH());
    let v2 = IUpgradesV2Dispatcher { contract_address: v1.contract_address };

    assert(v2.get_value() == VALUE, 'Should keep state after upgrade');
}

#[test]
#[available_gas(2000000)]
fn test_remove_selector_passes_in_v1() {
    let v1 = deploy_v1();
    v1.remove_selector();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_remove_selector_fails_in_v2() {
    let v1 = deploy_v1();
    v1.upgrade(V2_CLASS_HASH());
    // We use the v1 dispatcher because remove_selector is not in v2 interface
    v1.remove_selector();
}
