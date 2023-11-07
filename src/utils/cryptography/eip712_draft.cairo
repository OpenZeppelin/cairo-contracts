// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.1 (utils/cryptography/eip712_draft.cairo)

#[starknet::contract]
mod EIP712 {
    #[storage]
    struct Storage {
        EIP712_name: felt252,
        EIP712_version: felt252
    }

    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        self.EIP712_name.read()
    }

    #[external(v0)]
    fn version(self: @ContractState) -> felt252 {
        self.EIP712_version.read()
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, name: felt252, version: felt252) {
            self.EIP712_name.write(name);
            self.EIP712_version.write(version);
        }
    }
}
