#[starknet::contract]
mod SnakeAccountMock {
    use openzeppelin::account::Account;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, _public_key: felt252) {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::InternalImpl::initializer(ref unsafe_state, _public_key);
    }

    #[external(v0)]
    fn set_public_key(ref self: ContractState, new_public_key: felt252) {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::PublicKeyImpl::set_public_key(ref unsafe_state, new_public_key);
    }

    #[external(v0)]
    fn get_public_key(self: @ContractState) -> felt252 {
        let unsafe_state = Account::unsafe_new_contract_state();
        Account::PublicKeyImpl::get_public_key(@unsafe_state)
    }

    #[external(v0)]
    fn is_valid_signature(
        self: @ContractState, hash: felt252, signature: Array<felt252>
    ) -> felt252 {
        let unsafe_state = Account::unsafe_new_contract_state();
        Account::SRC6Impl::is_valid_signature(@unsafe_state, hash, signature)
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        let unsafe_state = Account::unsafe_new_contract_state();
        Account::SRC5Impl::supports_interface(@unsafe_state, interface_id)
    }
}
