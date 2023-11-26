// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.0 (security/reentrancyguard.cairo)

/// # ReentrancyGuard Component
///
/// The ReentrancyGuard component helps prevent nested (reentrant) calls
/// to a function.
#[starknet::component]
mod ReentrancyGuardComponent {
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ReentrancyGuard_entered: bool
    }

    mod Errors {
        const REENTRANT_CALL: felt252 = 'ReentrancyGuard: reentrant call';
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Prevents a contract's function from calling itself or another protected function, directly or indirectly.
        fn start(ref self: ComponentState<TContractState>) {
            assert(!self.ReentrancyGuard_entered.read(), Errors::REENTRANT_CALL);
            self.ReentrancyGuard_entered.write(true);
        }

        /// Removes the reentrant guard.
        fn end(ref self: ComponentState<TContractState>) {
            self.ReentrancyGuard_entered.write(false);
        }
    }
}
