// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.13.0 (governance/timelock/interface.cairo)

/// # TimelockController Component
///
///

use openzeppelin::governance::timelock::utils::OperationState;
use starknet::ContractAddress;
use openzeppelin::governance::timelock::utils::call_impls::Call;

#[starknet::interface]
trait ITimelock<TState> {
    fn is_operation(self: @TState, id: felt252) -> bool;
    fn is_operation_pending(self: @TState, id: felt252) -> bool;
    fn is_operation_ready(self: @TState, id: felt252) -> bool;
    fn is_operation_done(self: @TState, id: felt252) -> bool;
    fn get_timestamp(self: @TState, id: felt252) -> u64;
    fn get_operation_state(self: @TState, id: felt252) -> OperationState;
    fn get_min_delay(self: @TState) -> u64;
    fn hash_operation(
        self: @TState, call: Call, predecessor: felt252, salt: felt252
    ) -> felt252;
    fn hash_operation_batch(
        self: @TState, calls: Span<Call>, predecessor: felt252, salt: felt252
    ) -> felt252;
    fn schedule(
        ref self: TState, call: Call, predecessor: felt252, salt: felt252, delay: u64
    );
    fn schedule_batch(
        ref self: TState, calls: Span<Call>, predecessor: felt252, salt: felt252, delay: u64
    );
    fn cancel(ref self: TState, id: felt252);
    fn execute(ref self: TState, call: Call, predecessor: felt252, salt: felt252);
    fn execute_batch(ref self: TState, calls: Span<Call>, predecessor: felt252, salt: felt252);
    fn update_delay(ref self: TState, new_delay: u64);
}

#[starknet::interface]
trait ITimelockABI<TState> {
    fn is_operation(self: @TState, id: felt252) -> bool;
    fn is_operation_pending(self: @TState, id: felt252) -> bool;
    fn is_operation_ready(self: @TState, id: felt252) -> bool;
    fn is_operation_done(self: @TState, id: felt252) -> bool;
    fn get_timestamp(self: @TState, id: felt252) -> u64;
    fn get_operation_state(self: @TState, id: felt252) -> OperationState;
    fn get_min_delay(self: @TState) -> u64;
    fn hash_operation(
        self: @TState, call: Call, predecessor: felt252, salt: felt252
    ) -> felt252;
    fn hash_operation_batch(
        self: @TState, calls: Span<Call>, predecessor: felt252, salt: felt252
    ) -> felt252;
    fn schedule(
        ref self: TState, call: Call, predecessor: felt252, salt: felt252, delay: u64
    );
    fn schedule_batch(
        ref self: TState, calls: Span<Call>, predecessor: felt252, salt: felt252, delay: u64
    );
    fn cancel(ref self: TState, id: felt252);
    fn execute(ref self: TState, call: Call, predecessor: felt252, salt: felt252);
    fn execute_batch(ref self: TState, calls: Span<Call>, predecessor: felt252, salt: felt252);
    fn update_delay(ref self: TState, new_delay: u64);

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IAccessControl
    fn has_role(self: @TState, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @TState, role: felt252) -> felt252;
    fn grant_role(ref self: TState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TState, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: TState, role: felt252, account: ContractAddress);

    // IAccessControlCamel
    fn hasRole(self: @TState, role: felt252, account: ContractAddress) -> bool;
    fn getRoleAdmin(self: @TState, role: felt252) -> felt252;
    fn grantRole(ref self: TState, role: felt252, account: ContractAddress);
    fn revokeRole(ref self: TState, role: felt252, account: ContractAddress);
    fn renounceRole(ref self: TState, role: felt252, account: ContractAddress);

    // IERC721Receiver
    fn on_erc721_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252;

    // IERC721ReceiverCamel
    fn onERC721Received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252;

    // IERC1155Receiver
    fn on_erc1155_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252;
    fn on_erc1155_batch_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252;

    // IERC1155ReceiverCamel
    fn onERC1155Received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252;
    fn onERC1155BatchReceived(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenIds: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252;
}
