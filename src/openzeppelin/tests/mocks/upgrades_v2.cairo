// This contract is a mock used to test the core functionality of the upgrade functions.
// The functions are NOT PROTECTED.
// DO NOT USE IN PRODUCTION.

#[contract]
mod Upgrades_V2 {
    use openzeppelin::upgrades::upgradeable::Upgradeable;
    use starknet::{ class_hash::ClassHash, ContractAddress };

    struct Storage {
        value: felt252,
        value2: felt252,
    }

    #[external]
    fn upgrade(new_hash: ClassHash) {
        Upgradeable::_upgrade(new_hash);
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
