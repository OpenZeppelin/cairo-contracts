// This contract is a mock used to test the core functionality of the upgrade functions.
// The functions are NOT PROTECTED.
// DO NOT USE IN PRODUCTION.

use array::ArrayTrait;
use starknet::class_hash::ClassHash;

#[starknet::interface]
trait IUpgradesV1<TState> {
    fn upgrade(ref self: TState, new_hash: ClassHash);
    fn upgrade_and_call(
        ref self: TState, new_hash: ClassHash, selector: felt252, calldata: Span<felt252>
    );
    fn set_value(ref self: TState, val: felt252);
    fn get_value(self: @TState) -> felt252;
    fn remove_selector(self: @TState);
}

#[starknet::contract]
mod UpgradesV1 {
    use array::ArrayTrait;
    use openzeppelin::upgrades::upgradeable::Upgradeable;
    use starknet::class_hash::ClassHash;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        value: felt252
    }

    #[external(v0)]
    impl UpgradesV1Impl of super::IUpgradesV1<ContractState> {
        fn upgrade(ref self: ContractState, new_hash: ClassHash) {
            let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::_upgrade(ref unsafe_state, new_hash);
        }

        fn upgrade_and_call(
            ref self: ContractState, new_hash: ClassHash, selector: felt252, calldata: Span<felt252>
        ) {
            let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::_upgrade_and_call(
                ref unsafe_state, new_hash, selector, calldata
            );
        }

        fn set_value(ref self: ContractState, val: felt252) {
            self.value.write(val);
        }

        fn get_value(self: @ContractState) -> felt252 {
            self.value.read()
        }

        fn remove_selector(self: @ContractState) {}
    }
}
