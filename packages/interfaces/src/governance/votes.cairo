// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.2 (interfaces/src/governance/votes.cairo)

use starknet::ContractAddress;

/// Common interface for Votes-enabled contracts.
#[starknet::interface]
pub trait IVotes<TState> {
    /// Returns the current amount of votes that `account` has.
    fn get_votes(self: @TState, account: ContractAddress) -> u256;

    /// Returns the amount of votes that `account` had at a specific moment in the past.
    fn get_past_votes(self: @TState, account: ContractAddress, timepoint: u64) -> u256;

    /// Returns the total supply of votes available at a specific moment in the past.
    ///
    /// NOTE: This value is the sum of all available votes, which is not necessarily the sum of all
    /// delegated votes.
    /// Votes that have not been delegated are still part of total supply, even though they would
    /// not participate in a vote.
    fn get_past_total_supply(self: @TState, timepoint: u64) -> u256;

    /// Returns the delegate that `account` has chosen.
    fn delegates(self: @TState, account: ContractAddress) -> ContractAddress;

    /// Delegates votes from the sender to `delegatee`.
    fn delegate(ref self: TState, delegatee: ContractAddress);

    /// Delegates votes from `delegator` to `delegatee`.
    fn delegate_by_sig(
        ref self: TState,
        delegator: ContractAddress,
        delegatee: ContractAddress,
        nonce: felt252,
        expiry: u64,
        signature: Span<felt252>,
    );

    /// Returns the current timepoint determined by the contract’s operational mode, intended for
    /// use in time-sensitive logic.
    /// See https://eips.ethereum.org/EIPS/eip-6372#clock.
    ///
    /// Requirements:
    ///
    /// - This function MUST always be non-decreasing.
    fn clock(self: @TState) -> u64;

    /// Returns a description of the clock the contract is operating in.
    /// See https://eips.ethereum.org/EIPS/eip-6372#clock_mode.
    ///
    /// Requirements:
    ///
    /// - The output MUST be formatted like a URL query string, decodable in standard JavaScript.
    fn CLOCK_MODE(self: @TState) -> ByteArray;
}

/// Common interface to interact with the `Votes` component.
#[starknet::interface]
pub trait VotesABI<TState> {
    // Votes
    fn get_votes(self: @TState, account: ContractAddress) -> u256;
    fn get_past_votes(self: @TState, account: ContractAddress, timepoint: u64) -> u256;
    fn get_past_total_supply(self: @TState, timepoint: u64) -> u256;
    fn delegates(self: @TState, account: ContractAddress) -> ContractAddress;
    fn delegate(ref self: TState, delegatee: ContractAddress);
    fn delegate_by_sig(
        ref self: TState,
        delegator: ContractAddress,
        delegatee: ContractAddress,
        nonce: felt252,
        expiry: u64,
        signature: Span<felt252>,
    );

    // Nonces
    fn nonces(self: @TState, owner: ContractAddress) -> felt252;

    // Clock (ERC-6372)
    fn clock(self: @TState) -> u64;
    fn CLOCK_MODE(self: @TState) -> ByteArray;
}
