// This contract is a mock used to test the core functionality of the upgrade functions.
// The functions are NOT PROTECTED.
// DO NOT USE IN PRODUCTION.

use array::ArrayTrait;
use starknet::class_hash::ClassHash;

#[starknet::interface]
trait IUpgradesV2<TState> {
    fn upgrade(ref self: TState, impl_hash: ClassHash);
    fn upgrade_and_call(
        ref self: TState, impl_hash: ClassHash, selector: felt252, calldata: Span<felt252>
    );
    fn set_value(ref self: TState, val: felt252);
    fn set_value2(ref self: TState, val: felt252);
    fn get_value(self: @TState) -> felt252;
    fn get_value2(self: @TState) -> felt252;
}

trait UpgradesV2Trait<TState> {
    fn set_value(ref self: TState, val: felt252);
    fn set_value2(ref self: TState, val: felt252);
    fn get_value(self: @TState) -> felt252;
    fn get_value2(self: @TState) -> felt252;
}

#[starknet::contract]
mod UpgradesV2 {
    use array::ArrayTrait;
    use starknet::class_hash::ClassHash;
    use starknet::ContractAddress;
    use openzeppelin::upgrades::upgradeable::Upgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableTrait;

    #[storage]
    struct Storage {
        value: felt252,
        value2: felt252,
    }

    #[external(v0)]
    impl UpgradeableImpl of UpgradeableTrait<ContractState> {
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::UpgradeableImpl::upgrade(ref unsafe_state, impl_hash);
        }

        fn upgrade_and_call(
            ref self: ContractState,
            impl_hash: ClassHash,
            selector: felt252,
            calldata: Span<felt252>
        ) {
            let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::UpgradeableImpl::upgrade_and_call(
                ref unsafe_state, impl_hash, selector, calldata
            );
        }
    }

    #[external(v0)]
    impl UpgradesV2Impl of super::UpgradesV2Trait<ContractState> {
        fn set_value(ref self: ContractState, val: felt252) {
            self.value.write(val);
        }

        fn set_value2(ref self: ContractState, val: felt252) {
            self.value2.write(val);
        }

        fn get_value(self: @ContractState) -> felt252 {
            self.value.read()
        }

        fn get_value2(self: @ContractState) -> felt252 {
            self.value2.read()
        }
    }
}
