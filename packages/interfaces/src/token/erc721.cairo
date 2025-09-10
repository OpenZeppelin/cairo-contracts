// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.2
// (interfaces/src/token/erc721.cairo)

use starknet::ContractAddress;

pub const IERC721_ID: felt252 = 0x33eb2f84c309543403fd69f0d0f363781ef06ef6faeb0131ff16ea3175bd943;
pub const IERC721_METADATA_ID: felt252 =
    0xabbcd595a567dce909050a1038e055daccb3c42af06f0add544fa90ee91f25;
pub const IERC721_RECEIVER_ID: felt252 =
    0x3a0dff5f70d80458ad14ae37bb182a728e3c8cdda0402a5daa86620bdf910bc;
pub const IERC721_ENUMERABLE_ID: felt252 =
    0x16bc0f502eeaf65ce0b3acb5eea656e2f26979ce6750e8502a82f377e538c87;


#[starknet::interface]
pub trait IERC721<TState> {
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
}

#[starknet::interface]
pub trait IERC721Metadata<TState> {
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;
}

#[starknet::interface]
pub trait IERC721CamelOnly<TState> {
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn ownerOf(self: @TState, tokenId: u256) -> ContractAddress;
    fn safeTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    );
    fn transferFrom(ref self: TState, from: ContractAddress, to: ContractAddress, tokenId: u256);
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @TState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;
}

#[starknet::interface]
pub trait IERC721MetadataCamelOnly<TState> {
    fn tokenURI(self: @TState, tokenId: u256) -> ByteArray;
}

//
// ERC721 ABI
//

#[starknet::interface]
pub trait ERC721ABI<TState> {
    // IERC721
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IERC721Metadata
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;

    // IERC721CamelOnly
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn ownerOf(self: @TState, tokenId: u256) -> ContractAddress;
    fn safeTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    );
    fn transferFrom(ref self: TState, from: ContractAddress, to: ContractAddress, tokenId: u256);
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @TState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;

    // IERC721MetadataCamelOnly
    fn tokenURI(self: @TState, tokenId: u256) -> ByteArray;
}

//
// ERC721Receiver
//

#[starknet::interface]
pub trait IERC721Receiver<TState> {
    fn on_erc721_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) -> felt252;
}

#[starknet::interface]
pub trait IERC721ReceiverCamel<TState> {
    fn onERC721Received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    ) -> felt252;
}

#[starknet::interface]
pub trait ERC721ReceiverMixin<TState> {
    // IERC721Receiver
    fn on_erc721_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    ) -> felt252;

    // IERC721ReceiverCamel
    fn onERC721Received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>,
    ) -> felt252;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::interface]
pub trait IERC721Enumerable<TState> {
    fn total_supply(self: @TState) -> u256;
    fn token_by_index(self: @TState, index: u256) -> u256;
    fn token_of_owner_by_index(self: @TState, owner: ContractAddress, index: u256) -> u256;
}

#[starknet::interface]
pub trait ERC721EnumerableABI<TState> {
    fn total_supply(self: @TState) -> u256;
    fn token_by_index(self: @TState, index: u256) -> u256;
    fn token_of_owner_by_index(self: @TState, owner: ContractAddress, index: u256) -> u256;
    fn all_tokens_of_owner(self: @TState, owner: ContractAddress) -> Span<u256>;
}
