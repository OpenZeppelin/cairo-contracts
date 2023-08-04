#[starknet::contract]
mod CamelERC721Mock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::token::erc721::ERC721;
    use openzeppelin::token::erc721::ERC721::InternalImpl;
    use openzeppelin::token::erc721::ERC721::ERC721CamelOnlyImpl;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, symbol: felt252, tokenId: u256, uri: felt252
    ) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        InternalImpl::initializer(ref unsafe_state, name, symbol);
        InternalImpl::_mint(ref unsafe_state, get_caller_address(), tokenId);
        InternalImpl::_set_token_uri(ref unsafe_state, tokenId, uri);
    }

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
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
    fn tokenUri(self: @ContractState, tokenId: u256) -> felt252 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721MetadataCamelOnlyImpl::tokenUri(@unsafe_state, tokenId)
    }

    #[external(v0)]
    fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721CamelOnlyImpl::balanceOf(@unsafe_state, account)
    }

    #[external(v0)]
    fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721CamelOnlyImpl::ownerOf(@unsafe_state, tokenId)
    }

    #[external(v0)]
    fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721CamelOnlyImpl::getApproved(@unsafe_state, tokenId)
    }

    #[external(v0)]
    fn isApprovedForAll(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721CamelOnlyImpl::isApprovedForAll(@unsafe_state, owner, operator)
    }

    #[external(v0)]
    fn approve(ref self: ContractState, to: ContractAddress, tokenId: u256) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::approve(ref unsafe_state, to, tokenId)
    }

    #[external(v0)]
    fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721CamelOnlyImpl::setApprovalForAll(ref unsafe_state, operator, approved)
    }

    #[external(v0)]
    fn transferFrom(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
    ) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721CamelOnlyImpl::transferFrom(ref unsafe_state, from, to, tokenId)
    }

    #[external(v0)]
    fn safeTransferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721CamelOnlyImpl::safeTransferFrom(ref unsafe_state, from, to, tokenId, data)
    }
}
