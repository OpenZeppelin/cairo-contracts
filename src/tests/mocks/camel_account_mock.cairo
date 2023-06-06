#[account_contract]
mod CamelAccountMock {
    use openzeppelin::account::interface::Call;
    use openzeppelin::account::Account;
    use openzeppelin::utils::serde::SpanSerde;

    #[constructor]
    fn constructor(_publicKey: felt252) {
        Account::initializer(_publicKey);
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
