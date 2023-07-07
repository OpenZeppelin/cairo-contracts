#[account_contract]
mod CamelAccountMock {
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
    fn setPublicKey(newPublicKey: felt252) {
        Account::setPublicKey(newPublicKey);
    }

    #[view]
    fn getPublicKey() -> felt252 {
        Account::getPublicKey()
    }

    #[view]
    fn isValidSignature(hash: felt252, signature: Array<felt252>) -> felt252 {
        Account::isValidSignature(hash, signature)
    }

    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        Account::supportsInterface(interfaceId)
    }
}
