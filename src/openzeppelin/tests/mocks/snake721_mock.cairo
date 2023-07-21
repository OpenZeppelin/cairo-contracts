#[starknet::contract]
mod SnakeERC721Mock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::token::erc721::ERC721;
    use openzeppelin::token::erc721::ERC721::InternalImpl;
    use openzeppelin::token::erc721::ERC721::ERC721Impl;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, symbol: felt252, token_id: u256, uri: felt252
    ) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        InternalImpl::initializer(ref unsafe_state, name, symbol);
        InternalImpl::_mint(ref unsafe_state, get_caller_address(), token_id);
        InternalImpl::_set_token_uri(ref unsafe_state, token_id, uri);
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::SRC5Impl::supports_interface(@unsafe_state, interface_id)
    }

    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721MetadataImpl::name(@unsafe_state)
    }

    #[external(v0)]
    fn symbol(self: @ContractState) -> felt252 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721MetadataImpl::symbol(@unsafe_state)
    }

    #[external(v0)]
    fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721MetadataImpl::token_uri(@unsafe_state, token_id)
    }

    #[external(v0)]
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721Impl::balance_of(@unsafe_state, account)
    }

    #[external(v0)]
    fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721Impl::owner_of(@unsafe_state, token_id)
    }

    #[external(v0)]
    fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721Impl::get_approved(@unsafe_state, token_id)
    }

    #[external(v0)]
    fn is_approved_for_all(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721Impl::is_approved_for_all(@unsafe_state, owner, operator)
    }

    #[external(v0)]
    fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721Impl::approve(ref unsafe_state, to, token_id)
    }

    #[external(v0)]
    fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721Impl::set_approval_for_all(ref unsafe_state, operator, approved)
    }

    #[external(v0)]
    fn transfer_from(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    ) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721Impl::transfer_from(ref unsafe_state, from, to, token_id)
    }

    #[external(v0)]
    fn safe_transfer_from(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721Impl::safe_transfer_from(ref unsafe_state, from, to, token_id, data)
    }
}
