#[contract]
mod ERC721 {
    use starknet::get_caller_address;
    use erc721_lib::ERC721Library;

    #[constructor]
    fn constructor(name: felt, symbol: felt, ) {
        ERC721Library::initializer(name, symbol);
    }

    #[view]
    fn name() -> felt {
        ERC721Library::name()
    }

    #[view]
    fn symbol() -> felt {
        ERC721Library::symbol()
    }

    #[view]
    fn balanceOf(account: felt) -> u256 {
        ERC721Library::balance_of(account)
    }

    #[view]
    fn ownerOf(tokenId: u256) -> felt {
        ERC721Library::owner_of(tokenId)
    }

    #[view]
    fn getApproved(tokenId: u256) -> felt {
        ERC721Library::get_approved(tokenId)
    }

    #[view]
    fn isApprovedForAll(owner: felt, operator: felt) -> bool {
        ERC721Library::is_approved_for_all(owner, operator)
    }

    #[view]
    fn tokenURI(tokenId: u256) -> felt {
        ERC721Library::token_uri(tokenId)
    }

    #[view]
    fn supportsInterface(interface_id: u32) -> bool {
        // TODO ERC165
        ERC721Library::supports_interface(interface_id)
    }

    #[external]
    fn approve(to: felt, tokenId: u256) {
        ERC721Library::approve(to, tokenId);
    }

    #[external]
    fn setApprovalForAll(operator: felt, approved: bool) {
        ERC721Library::set_approval_for_all(operator, approved);
    }

    #[external]
    fn transferFrom(from_: felt, to: felt, tokenId: u256) {
        ERC721Library::transfer_from(from_, to, tokenId);
    }
}