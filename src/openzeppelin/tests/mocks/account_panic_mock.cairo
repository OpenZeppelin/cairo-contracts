// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// false for bool
// empty array for Array<Span<felt252>>

#[account_contract]
mod SnakeAccountPanicMock {
    use openzeppelin::account::interface::Call;
    use openzeppelin::utils::serde::SpanSerde;

    #[external]
    fn __execute__(mut calls: Array<Call>) -> Array<Span<felt252>> {
        panic_with_felt252('Some error');
        ArrayTrait::new()
    }

    #[external]
    fn __validate__(mut calls: Array<Call>) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

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
    use openzeppelin::account::interface::Call;
    use openzeppelin::utils::serde::SpanSerde;

    #[external]
    fn __execute__(mut calls: Array<Call>) -> Array<Span<felt252>> {
        panic_with_felt252('Some error');
        ArrayTrait::new()
    }

    #[external]
    fn __validate__(mut calls: Array<Call>) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

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
