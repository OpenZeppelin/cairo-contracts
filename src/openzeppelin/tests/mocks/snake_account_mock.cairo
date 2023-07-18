#[starknet::contract]
mod SnakeAccountMock {
    use openzeppelin::account::interface::Call;
    use openzeppelin::account::Account;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, _public_key: felt252) {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::InternalImpl::initializer(ref unsafe_state, _public_key);
    }

    #[external(v0)]
    fn __execute__(self: @ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::SRC6Impl::__execute__(@unsafe_state, calls)
    }

    #[external(v0)]
    fn __validate__(self: @ContractState, mut calls: Array<Call>) -> felt252 {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::SRC6Impl::__validate__(@unsafe_state, calls)
    }

    #[external(v0)]
    fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::DeclarerImpl::__validate_declare__(@unsafe_state, class_hash)
    }

    #[external(v0)]
    fn __validate_deploy__(
        self: @ContractState,
        class_hash: felt252,
        contract_address_salt: felt252,
        _public_key: felt252
    ) -> felt252 {
        let mut unsafe_state = Account::unsafe_new_contract_state();
        Account::__validate_deploy__(@unsafe_state, class_hash, contract_address_salt, _public_key)
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
