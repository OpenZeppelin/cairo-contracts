// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (security/pausable.cairo)

#[starknet::interface]
trait IPausable<TState> {
    fn is_paused(self: @TState) -> bool;
}

#[starknet::component]
mod Pausable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        Pausable_paused: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Paused: Paused,
        Unpaused: Unpaused,
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {
        account: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct Unpaused {
        account: ContractAddress
    }

    mod Errors {
        const PAUSED: felt252 = 'Pausable: paused';
        const NOT_PAUSED: felt252 = 'Pausable: not paused';
    }

    #[embeddable_as(PausableImpl)]
    impl Pausable<
        TContractState, +HasComponent<TContractState>
    > of super::IPausable<ComponentState<TContractState>> {
        fn is_paused(self: @ComponentState<TContractState>) -> bool {
            self.Pausable_paused.read()
        }
    }

    trait InternalTrait<TContractState> {
        fn assert_not_paused(self: @TContractState);
        fn assert_paused(self: @TContractState);
        fn _pause(ref self: TContractState);
        fn _unpause(ref self: TContractState);
    }

    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<ComponentState<TContractState>> {
        fn assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self.Pausable_paused.read(), Errors::PAUSED);
        }

        fn assert_paused(self: @ComponentState<TContractState>) {
            assert(self.Pausable_paused.read(), Errors::NOT_PAUSED);
        }

        fn _pause(ref self: ComponentState<TContractState>) {
            self.assert_not_paused();
            self.Pausable_paused.write(true);
            self.emit(Paused { account: get_caller_address() });
        }

        fn _unpause(ref self: ComponentState<TContractState>) {
            self.assert_paused();
            self.Pausable_paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
        }
    }
}
