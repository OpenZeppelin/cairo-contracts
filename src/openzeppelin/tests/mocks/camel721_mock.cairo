#[contract]
mod CamelERC721Mock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::token::erc721::ERC721;
    use openzeppelin::utils::serde::SpanSerde;

    #[constructor]
    fn constructor(name: felt252, symbol: felt252, tokenId: u256, uri: felt252) {
        ERC721::initializer(name, symbol);
        ERC721::_mint(get_caller_address(), tokenId);
        ERC721::_set_token_uri(tokenId, uri);
    }

    // View

    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        ERC721::supports_interface(interfaceId)
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
    fn tokenUri(tokenId: u256) -> felt252 {
        ERC721::tokenUri(tokenId)
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
        ERC721::balanceOf(account)
    }

    #[view]
    fn ownerOf(tokenId: u256) -> ContractAddress {
        ERC721::ownerOf(tokenId)
    }

    #[view]
    fn getApproved(tokenId: u256) -> ContractAddress {
        ERC721::getApproved(tokenId)
    }

    #[view]
    fn isApprovedForAll(owner: ContractAddress, operator: ContractAddress) -> bool {
        ERC721::isApprovedForAll(owner, operator)
    }

    // External

    #[external]
    fn approve(to: ContractAddress, tokenId: u256) {
        ERC721::approve(to, tokenId)
    }

    #[external]
    fn setApprovalForAll(operator: ContractAddress, approved: bool) {
        ERC721::setApprovalForAll(operator, approved)
    }

    #[external]
    fn transferFrom(from: ContractAddress, to: ContractAddress, tokenId: u256) {
        ERC721::transferFrom(from, to, tokenId)
    }

    #[external]
    fn safeTransferFrom(
        from: ContractAddress, to: ContractAddress, tokenId: u256, data: Span<felt252>
    ) {
        ERC721::safeTransferFrom(from, to, tokenId, data)
    }
}
