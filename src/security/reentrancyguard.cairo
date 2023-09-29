// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (security/reentrancyguard.cairo)

#[starknet::contract]
mod ReentrancyGuard {
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ReentrancyGuard_entered: bool
    }

    mod Errors {
        const REENTRANT_CALL: felt252 = 'ReentrancyGuard: reentrant call';
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn start(ref self: ContractState) {
            assert(!self.ReentrancyGuard_entered.read(), Errors::REENTRANT_CALL);
            self.ReentrancyGuard_entered.write(true);
        }

        fn end(ref self: ContractState) {
            self.ReentrancyGuard_entered.write(false);
        }
    }
}
