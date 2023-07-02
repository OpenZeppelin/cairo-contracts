use openzeppelin::utils::serde::SpanSerde;
use starknet::ContractAddress;
use array::SpanTrait;

const IERC721_ID: felt252 = 0x33eb2f84c309543403fd69f0d0f363781ef06ef6faeb0131ff16ea3175bd943;
const IERC721_METADATA_ID: felt252 =
    0x6069a70848f907fa57668ba1875164eb4dcee693952468581406d131081bbd;
const IERC721_RECEIVER_ID: felt252 =
    0x3a0dff5f70d80458ad14ae37bb182a728e3c8cdda0402a5daa86620bdf910bc;

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
trait ERC721ReceiverABI {
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> felt252;
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> felt252;
}

trait IERC721Receiver {
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> felt252;
}

trait IERC721ReceiverCamel {
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> felt252;
}
