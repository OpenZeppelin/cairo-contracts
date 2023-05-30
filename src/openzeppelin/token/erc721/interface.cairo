use openzeppelin::utils::serde::SpanSerde;
use starknet::ContractAddress;
use array::SpanTrait;

const IERC721_ID: u32 = 0x80ac58cd_u32;
const IERC721_METADATA_ID: u32 = 0x5b5e139f_u32;
const IERC721_RECEIVER_ID: u32 = 0x150b7a02_u32;

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
    ) -> u32;
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> u32;
}

#[abi]
trait IERC721Receiver {
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> u32;
}

#[abi]
trait IERC721ReceiverCamel {
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> u32;
}
