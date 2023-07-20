// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// false for bool

#[starknet::contract]
mod SnakeAccountPanicMock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn set_public_key(ref self: ContractState, new_public_key: felt252) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn get_public_key(self: @ContractState) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn is_valid_signature(
        self: @ContractState, hash: felt252, signature: Array<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[starknet::contract]
mod CamelAccountPanicMock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn setPublicKey(ref self: ContractState, newPublicKey: felt252) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn getPublicKey(self: @ContractState) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn isValidSignature(self: @ContractState, hash: felt252, signature: Array<felt252>) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}
