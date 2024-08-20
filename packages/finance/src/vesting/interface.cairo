// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (finance/vesting/interface.cairo)

use starknet::ContractAddress;

#[starknet::interface]
pub trait IVesting<TState> {
    fn start(self: @TState) -> u64;
    fn cliff(self: @TState) -> u64;
    fn duration(self: @TState) -> u64;
    fn end(self: @TState) -> u64;
    fn released(self: @TState, token: ContractAddress) -> u256;
    fn releasable(self: @TState, token: ContractAddress) -> u256;
    fn vested_amount(self: @TState, token: ContractAddress, timestamp: u64) -> u256;

    fn release(ref self: TState, token: ContractAddress) -> u256;
}
