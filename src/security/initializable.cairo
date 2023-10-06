// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (security/initializable.cairo)

#[starknet::contract]
mod Initializable {
    #[storage]
    struct Storage {
        Initializable_initialized: bool
    }

    mod Errors {
        const INITIALIZED: felt252 = 'Initializable: is initialized';
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn is_initialized(self: @ContractState) -> bool {
            self.Initializable_initialized.read()
        }

        fn initialize(ref self: ContractState) {
            assert(!self.is_initialized(), Errors::INITIALIZED);
            self.Initializable_initialized.write(true);
        }
    }
}
