use starknet::class_hash::ClassHash;

#[starknet::interface]
trait IUpgradeable<TState> {
    fn upgrade(ref self: TState, impl_hash: ClassHash);
    fn upgrade_and_call(ref self: TState, impl_hash: ClassHash, selector: felt252, calldata: Span<felt252>);
}

#[starknet::contract]
mod Upgradeable {
    use array::ArrayTrait;
    use starknet::class_hash::ClassHash;
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use starknet::SyscallResult;
    use zeroable::Zeroable;
    use super::IUpgradeable;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash
    }

    #[external(v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            self._upgrade(impl_hash);
        }

        fn upgrade_and_call(ref self: ContractState, impl_hash: ClassHash, selector: felt252, calldata: Span<felt252>) {
            self._upgrade_and_call(impl_hash, selector, calldata);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalState {
        fn _upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(impl_hash).unwrap_syscall();
            self.emit(Upgraded { implementation: impl_hash });
        }

        fn _upgrade_and_call(ref self: ContractState, impl_hash: ClassHash, selector: felt252, calldata: Span<felt252>) {
            self._upgrade(impl_hash);
            // The call_contract syscall is used in order to call a selector from the new class.
            // See: https://docs.starknet.io/documentation/architecture_and_concepts/Contracts/system-calls-cairo1/#replace_class
            starknet::call_contract_syscall(get_contract_address(), selector, calldata)
                .unwrap_syscall();
        }
    }
}
