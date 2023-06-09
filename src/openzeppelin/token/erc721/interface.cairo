use openzeppelin::utils::serde::SpanSerde;
use starknet::ContractAddress;
use array::SpanTrait;

const IERC721_ID: felt252 = 0x36f39777e577db64d712f3a828ecd73eeeb0964430a821ee1587a3b03a65f3a;
const IERC721_METADATA_ID: felt252 =
    0x1a171894adf749940f34aa3cdbc821f8afb7d631cdf68543f1eeb3c2c3d4030;
const IERC721_RECEIVER_ID: felt252 =
    0x2a367c13e24632fd4addeb9b26e5625f5afda07d6c5834989c7c4ac27db7616;

#[abi]
trait IERC721 {
    fn balance_of(account: ContractAddress) -> u256;
    fn owner_of(token_id: u256) -> ContractAddress;
    fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256);
    fn safe_transfer_from(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    );
    fn approve(to: ContractAddress, token_id: u256);
    fn set_approval_for_all(operator: ContractAddress, approved: bool);
    fn get_approved(token_id: u256) -> ContractAddress;
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool;
    // IERC721Metadata
    fn name() -> felt252;
    fn symbol() -> felt252;
    fn token_uri(token_id: u256) -> felt252;
}

#[abi]
trait IERC721Camel {
    fn balanceOf(account: ContractAddress) -> u256;
    fn ownerOf(tokenId: u256) -> ContractAddress;
    fn transferFrom(from: ContractAddress, to: ContractAddress, tokenId: u256);
    fn safeTransferFrom(
        from: ContractAddress, to: ContractAddress, tokenId: u256, data: Span<felt252>
    );
    fn approve(to: ContractAddress, tokenId: u256);
    fn setApprovalForAll(operator: ContractAddress, approved: bool);
    fn getApproved(tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(owner: ContractAddress, operator: ContractAddress) -> bool;
    // IERC721Metadata
    fn name() -> felt252;
    fn symbol() -> felt252;
    fn tokenUri(tokenId: u256) -> felt252;
}

//
// ERC721Receiver
//

#[abi]
trait IERC721ReceiverABI {
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> felt252;
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> felt252;
}

#[abi]
trait IERC721Receiver {
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> felt252;
}

#[abi]
trait IERC721ReceiverCamel {
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> felt252;
}
