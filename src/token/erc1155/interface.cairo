// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (token/erc1155/interface.cairo)

use starknet::ContractAddress;

const IERC1155_ID: felt252 = 0xdef955e77a50cefb767c39f5e3bacb4d24f75e2de1d930ae214fcd6f7d42f3;
const IERC1155_METADATA_ID: felt252 = 
    0x3d7b708e1a6bd1a69c8d4deedf7ad6adc6cda9cc81bd97c49dc1c82e172d1fc;
const IERC1155_RECEIVER_ID: felt252 = 
    0x15e8665b5af20040c3af1670509df02eb916375cdf7d8cbaf7bd553a257515e;


#[starknet::interface]
trait IERC1155<TState> {
    fn balance_of(self: @TState, account: ContractAddress, id: u256) -> u256;
    fn balance_of_batch(self: @TState, accounts: Span<ContractAddress>, ids: Span<u256>) -> Span<u256>;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        value: u256,
        data: Span<felt252>
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, value: u256);
    fn safe_batch_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    );
    fn batch_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
    );
    fn is_approved_for_all(
        self: @TState,
        account: ContractAddress,
        operator: ContractAddress
    ) -> bool;
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
}

#[starknet::interface]
trait IERC1155Metadata<TState> {
    fn uri(self: @TState, uri: u256) -> felt252;
}

#[starknet::interface]
trait IERC1155CamelOnly<TState> {
    fn balanceOf(self: @TState, account: ContractAddress, id: u256) -> u256;
    fn balanceOfBatch(self: @TState, accounts: Span<ContractAddress>, ids: Span<u256>) -> Span<u256>;
    fn safeTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        value: u256,
        data: Span<felt252>
    );
    fn transferFrom(ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, value: u256);
    fn safeBatchTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    );
    fn batchTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
    );
    fn isApprovedForAll(
        self: @TState,
        account: ContractAddress,
        operator: ContractAddress
    ) -> bool;
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);
}

//
// ERC1155 ABI
//

#[starknet::interface]
trait ERC1155ABI<TState> {
    // IERC1155
    fn balance_of(self: @TState, account: ContractAddress, id: u256) -> u256;
    fn balance_of_batch(self: @TState, accounts: Span<ContractAddress>, ids: Span<u256>) -> Span<u256>;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        value: u256,
        data: Span<felt252>
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, value: u256);
    fn safe_batch_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    );
    fn batch_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
    );
    fn is_approved_for_all(
        self: @TState,
        account: ContractAddress,
        operator: ContractAddress
    ) -> bool;
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IERC1155Metadata
    fn uri(self: @TState, id: u256) -> felt252;

    // IERC1155CamelOnly
    fn balanceOf(self: @TState, account: ContractAddress, id: u256) -> u256;
    fn balanceOfBatch(self: @TState, accounts: Span<ContractAddress>, ids: Span<u256>) -> Span<u256>;
    fn safeTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        value: u256,
        data: Span<felt252>
    );
    fn transferFrom(ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, value: u256);
    fn safeBatchTransferFrom(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    );
    fn isApprovedForAll(
        self: @TState,
        account: ContractAddress,
        operator: ContractAddress
    ) -> bool;
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);

    // ISRC5Camel
    fn supportsInterface(self: @TState, interfaceId: felt252) -> bool;
}

//
// IERC1155Receiver
//

#[starknet::interface]
trait IERC1155Receiver<TState> {
    fn on_erc1155_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252;
    fn on_erc1155_batch_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252;
}
#[starknet::interface]
trait IERC1155ReceiverCamel<TState> {
    fn onERC1155Received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252;
    fn onERC1155BatchReceived(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252;
}
