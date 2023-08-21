// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (utils/cryptography/eip712_draft.cairo)

#[starknet::contract]
mod EIP712 {
    #[storage]
    struct Storage {
        _name: felt252,
        _version: felt252
    }

    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        self._name.read()
    }

    #[external(v0)]
    fn version(self: @ContractState) -> felt252 {
        self._version.read()
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, name: felt252, version: felt252) {
            self._name.write(name);
            self._version.write(version);
        }
    }
}
