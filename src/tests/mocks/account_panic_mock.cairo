// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// false for bool

#[account_contract]
mod SnakeAccountPanicMock {
    #[external]
    fn set_public_key(new_public_key: felt252) {
        panic_with_felt252('Some error');
    }

    #[view]
    fn get_public_key() -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn is_valid_signature(hash: felt252, signature: Array<felt252>) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[account_contract]
mod CamelAccountPanicMock {
    #[external]
    fn setPublicKey(newPublicKey: felt252) {
        panic_with_felt252('Some error');
    }

    #[view]
    fn getPublicKey() -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn isValidSignature(hash: felt252, signature: Array<felt252>) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}
