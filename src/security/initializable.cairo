// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (security/initializable.cairo)

#[starknet::contract]
mod Initializable {
    #[storage]
    struct Storage {
        initialized: bool
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn is_initialized(self: @ContractState) -> bool {
            self.initialized.read()
        }

        fn initialize(ref self: ContractState) {
            assert(!self.is_initialized(), 'Initializable: is initialized');
            self.initialized.write(true);
        }
    }
}
