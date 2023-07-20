#[starknet::contract]
mod CamelAccountMock {
    use openzeppelin::account::Account;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, _publicKey: felt252) {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::InternalImpl::initializer(ref unsafe_state, _publicKey);
    }

    #[external(v0)]
    fn setPublicKey(ref self: ContractState, newPublicKey: felt252) {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::PublicKeyCamelImpl::setPublicKey(ref unsafe_state, newPublicKey);
    }

    #[external(v0)]
    fn getPublicKey(self: @ContractState) -> felt252 {
        let unsafe_state = Account::unsafe_new_contract_state();
        Account::PublicKeyCamelImpl::getPublicKey(@unsafe_state)
    }

    #[external(v0)]
    fn isValidSignature(self: @ContractState, hash: felt252, signature: Array<felt252>) -> felt252 {
        let unsafe_state = Account::unsafe_new_contract_state();
        Account::SRC6CamelOnlyImpl::isValidSignature(@unsafe_state, hash, signature)
    }

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        let unsafe_state = Account::unsafe_new_contract_state();
        Account::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
    }
}
