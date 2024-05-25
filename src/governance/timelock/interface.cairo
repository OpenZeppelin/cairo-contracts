// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.13.0 (governance/timelock/interface.cairo)

/// # TimelockController Component
///
///

use starknet::ContractAddress;
use starknet::account::Call;

#[derive(Drop, Copy, Serde, PartialEq)]
enum OperationState {
    Unset,
    Waiting,
    Ready,
    Done
}

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
        self: @TState, calls: Span<Call>, predecessor: felt252, salt: felt252
    ) -> felt252;
    fn schedule(
        ref self: TState, calls: Span<Call>, predecessor: felt252, salt: felt252, delay: u64
    );
    fn cancel(ref self: TState, id: felt252);
    fn execute(ref self: TState, calls: Span<Call>, predecessor: felt252, salt: felt252);
    fn update_delay(ref self: TState, new_delay: u64);
}
