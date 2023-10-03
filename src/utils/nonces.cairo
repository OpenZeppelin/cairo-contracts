// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (utils/nonces.cairo)

#[starknet::contract]
mod Nonces {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        Nonces_nonces: LegacyMap<ContractAddress, felt252>
    }

    mod Errors {
        const INVALID_NONCE: felt252 = 'Nonces: invalid nonce';
    }

    /// Returns the next unused nonce for an address.
    #[external(v0)]
    fn nonces(self: @ContractState, owner: ContractAddress) -> felt252 {
        self.Nonces_nonces.read(owner)
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Consumes a nonce, returns the current value, and increments nonce.
        fn use_nonce(ref self: ContractState, owner: ContractAddress) -> felt252 {
            // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
            // decremented or reset. This guarantees that the nonce never overflows.
            let nonce = self.Nonces_nonces.read(owner);
            self.Nonces_nonces.write(owner, nonce + 1);
            nonce
        }

        /// Same as {_use_nonce} but checking that `nonce` is the next valid for `owner`.
        fn use_checked_nonce(
            ref self: ContractState, owner: ContractAddress, nonce: felt252
        ) -> felt252 {
            let current = self.use_nonce(owner);
            assert(nonce == current, Errors::INVALID_NONCE);
            current
        }
    }
}
