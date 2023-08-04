// This contract is a mock used to test the core functionality of the upgrade functions.
// The functions are NOT PROTECTED.
// DO NOT USE IN PRODUCTION.

use array::ArrayTrait;
use starknet::ClassHash;

#[starknet::interface]
trait IUpgradesV1<TState> {
    fn upgrade(ref self: TState, impl_hash: ClassHash);
    fn set_value(ref self: TState, val: felt252);
    fn get_value(self: @TState) -> felt252;
    fn remove_selector(self: @TState);
}

trait UpgradesV1Trait<TState> {
    fn set_value(ref self: TState, val: felt252);
    fn get_value(self: @TState) -> felt252;
    fn remove_selector(self: @TState);
}

#[starknet::contract]
mod UpgradesV1 {
    use array::ArrayTrait;
    use starknet::ClassHash;
    use starknet::ContractAddress;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::Upgradeable;

    #[storage]
    struct Storage {
        value: felt252
    }

    #[external(v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::_upgrade(ref unsafe_state, impl_hash);
        }
    }

    #[external(v0)]
    impl UpgradesV1Impl of super::UpgradesV1Trait<ContractState> {
        fn set_value(ref self: ContractState, val: felt252) {
            self.value.write(val);
        }

        fn get_value(self: @ContractState) -> felt252 {
            self.value.read()
        }

        fn remove_selector(self: @ContractState) {}
    }
}
