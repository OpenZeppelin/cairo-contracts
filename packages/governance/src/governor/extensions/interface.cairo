// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (governance/governor/extensions/interface.cairo)

#[starknet::interface]
pub trait IQuorumFraction<TState> {
    /// Returns the current quorum numerator.
    fn current_quorum_numerator(self: @TState) -> u256;

    /// Returns the quorum numerator at a specific timepoint.
    fn quorum_numerator(self: @TState, timepoint: u64) -> u256;

    /// Returns the quorum denominator.
    fn quorum_denominator(self: @TState) -> u256;
}
