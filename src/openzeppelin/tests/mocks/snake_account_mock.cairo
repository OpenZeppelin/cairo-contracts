#[account_contract]
mod SnakeAccountMock {
    use openzeppelin::account::interface::Call;
    use openzeppelin::account::Account;
    use openzeppelin::utils::serde::SpanSerde;

    #[external]
    fn __execute__(mut calls: Array<Call>) -> Array<Span<felt252>> {
        Account::__execute__(calls)
    }

    #[external]
    fn __validate__(mut calls: Array<Call>) -> felt252 {
        Account::__validate__(calls)
    }

    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252 {
        Account::__validate_declare__(class_hash)
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252 {
        Account::__validate_deploy__(class_hash, contract_address_salt, _public_key)
    }

    #[external]
    fn set_public_key(new_public_key: felt252) {
        Account::set_public_key(new_public_key);
    }

    #[view]
    fn get_public_key() -> felt252 {
        Account::get_public_key()
    }

    #[view]
    fn is_valid_signature(hash: felt252, signature: Array<felt252>) -> felt252 {
        Account::is_valid_signature(hash, signature)
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        Account::supports_interface(interface_id)
    }
}
