// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.0 (security/initializable.cairo)

/// # Initializable Component
///
/// The Initializable component provides a simple mechanism that executes
/// logic once and only once. This can be useful for setting a contract's
/// initial state in scenarios where a constructor cannot be used.
#[starknet::component]
mod InitializableComponent {
    use openzeppelin::security::interface::IInitializable;

    #[storage]
    struct Storage {
        Initializable_initialized: bool
    }

    mod Errors {
        const INITIALIZED: felt252 = 'Initializable: is initialized';
    }

    #[embeddable_as(InitializableImpl)]
    impl Initializable<
        TContractState, +HasComponent<TContractState>
    > of IInitializable<ComponentState<TContractState>> {
        /// Returns true if the using contract executed `initialize`.
        fn is_initialized(self: @ComponentState<TContractState>) -> bool {
            self.Initializable_initialized.read()
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Ensures the calling function can only be called once.
        fn initialize(ref self: ComponentState<TContractState>) {
            assert(!self.is_initialized(), Errors::INITIALIZED);
            self.Initializable_initialized.write(true);
        }
    }
}
