// This contract is a mock used to test the core functionality of the upgrade functions.
// The functions are NOT PROTECTED.
// DO NOT USE IN PRODUCTION.

use array::ArrayTrait;
use starknet::class_hash::ClassHash;

#[abi]
trait IUpgrades_V2 {
    fn upgrade(new_hash: ClassHash);
    fn upgrade_and_call(new_hash: ClassHash, selector: felt252, calldata: Array<felt252>);
    fn set_value(val: felt252);
    fn set_value2(val: felt252);
    fn get_value() -> felt252;
    fn get_value2() -> felt252;
}

#[contract]
mod Upgrades_V2 {
    use array::ArrayTrait;
    use openzeppelin::upgrades::upgradeable::Upgradeable;
    use starknet::class_hash::ClassHash;
    use starknet::ContractAddress;

    struct Storage {
        value: felt252,
        value2: felt252,
    }

    #[external]
    fn upgrade(new_hash: ClassHash) {
        Upgradeable::_upgrade(new_hash);
    }

    #[external]
    fn upgrade_and_call(new_hash: ClassHash, selector: felt252, calldata: Array<felt252>) {
        Upgradeable::_upgrade_and_call(new_hash, selector, calldata);
    }

    #[external]
    fn set_value(val: felt252) {
        value::write(val);
    }

    #[external]
    fn set_value2(val: felt252) {
        value2::write(val);
    }

    #[view]
    fn get_value() -> felt252 {
        value::read()
    }

    #[view]
    fn get_value2() -> felt252 {
        value2::read()
    }
}
