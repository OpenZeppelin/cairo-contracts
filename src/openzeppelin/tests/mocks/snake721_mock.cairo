#[contract]
mod SnakeERC721Mock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::token::erc721::ERC721;
    use openzeppelin::utils::serde::SpanSerde;

    #[constructor]
    fn constructor(name: felt252, symbol: felt252, token_id: u256, uri: felt252) {
        ERC721::initializer(name, symbol);
        ERC721::_mint(get_caller_address(), token_id);
        ERC721::_set_token_uri(token_id, uri);
    }

    // View

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        ERC721::supports_interface(interface_id)
    }

    #[view]
    fn name() -> felt252 {
        ERC721::name()
    }

    #[view]
    fn symbol() -> felt252 {
        ERC721::symbol()
    }

    #[view]
    fn token_uri(token_id: u256) -> felt252 {
        ERC721::token_uri(token_id)
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        ERC721::balance_of(account)
    }

    #[view]
    fn owner_of(token_id: u256) -> ContractAddress {
        ERC721::owner_of(token_id)
    }

    #[view]
    fn get_approved(token_id: u256) -> ContractAddress {
        ERC721::get_approved(token_id)
    }

    #[view]
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool {
        ERC721::is_approved_for_all(owner, operator)
    }

    // External

    #[external]
    fn approve(to: ContractAddress, token_id: u256) {
        ERC721::approve(to, token_id)
    }

    #[external]
    fn set_approval_for_all(operator: ContractAddress, approved: bool) {
        ERC721::set_approval_for_all(operator, approved)
    }

    #[external]
    fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256) {
        ERC721::transfer_from(from, to, token_id)
    }

    #[external]
    fn safe_transfer_from(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) {
        ERC721::safe_transfer_from(from, to, token_id, data)
    }
}
