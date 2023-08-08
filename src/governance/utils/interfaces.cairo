use starknet::ContractAddress;

/// Common interface for {Votes}-enabled contracts.
#[starknet::interface]
trait IVotes<TState> {
    /// Returns the current amount of votes that `account` has.
    fn getVotes(self: @TState, account: ContractAddress) -> u256;

    // /// Returns the amount of votes that `account` had at a specific moment in the past. If the `clock()` is
    // /// configured to use block numbers, this will return the value at the end of the corresponding block.
    // fn getPastVotes(self: @TState, account: ContractAddress, timepoint: u64) -> u256;

    // /// Returns the total supply of votes available at a specific moment in the past. If the `clock()` is
    // /// configured to use block numbers, this will return the value at the end of the corresponding block.
    // ///
    // /// NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
    // /// Votes that have not been delegated are still part of total supply, even though they would not participate in a
    // /// vote.
    // fn getPastTotalSupply(self: @TState, timepoint: u64) -> u256;

    // /// Returns the delegate that `account` has chosen.
    // fn delegates(self: @TState, account: ContractAddress) -> ContractAddress;

    // /// Delegates votes from the sender to `delegatee`.
    // fn delegate(ref self: TState, delegatee: ContractAddress);

    // /// Delegates votes from signer to `delegatee`.
    // fn delegateBySig(
    //     ref self: TState,
    //     delegatee: ContractAddress,
    //     nonce: felt252,
    //     expiry: felt252,
    //     v: u8,
    //     r: u32,
    //     s: u32
    // );
}
