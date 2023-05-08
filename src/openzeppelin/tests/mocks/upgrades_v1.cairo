// This contract is a mock used to test the core functionality of the upgrade functions.
// The functions are NOT PROTECTED.
// DO NOT USE IN PRODUCTION.

#[contract]
mod Upgrades_V1 {
    use array::ArrayTrait;
    use openzeppelin::upgrades::upgradeable::Upgradeable;
    use starknet::{class_hash::ClassHash, ContractAddress};

    struct Storage {
        value: felt252
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
    fn remove_selector() {}

    #[view]
    fn get_value() -> felt252 {
        value::read()
    }
}
