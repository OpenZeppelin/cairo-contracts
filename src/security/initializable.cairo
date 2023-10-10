// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (security/initializable.cairo)

/// # Initializable Component
///
/// The Initializable component provides a simple mechanism that executes
/// logic once and only once. This can be useful for setting a contract's
/// initial state in scenarios where a constructor cannot be used.
#[starknet::component]
mod Initializable {
    #[storage]
    struct Storage {
        Initializable_initialized: bool
    }

    mod Errors {
        const INITIALIZED: felt252 = 'Initializable: is initialized';
    }

    trait InternalTrait<TContractState> {
        fn is_initialized(self: @TContractState) -> bool;
        fn initialize(ref self: TContractState);
    }

    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<ComponentState<TContractState>> {
        /// Returns true if the using contract executed `initialize`.
        fn is_initialized(self: @ComponentState<TContractState>) -> bool {
            self.Initializable_initialized.read()
        }

        /// Ensures the calling function can only be called once.
        fn initialize(ref self: ComponentState<TContractState>) {
            assert(!self.is_initialized(), Errors::INITIALIZED);
            self.Initializable_initialized.write(true);
        }
    }
}
