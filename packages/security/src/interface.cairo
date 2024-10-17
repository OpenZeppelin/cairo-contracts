// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (security/interface.cairo)

#[starknet::interface]
pub trait IInitializable<TState> {
    fn is_initialized(self: @TState) -> bool;
}

#[starknet::interface]
pub trait IPausable<TState> {
    fn is_paused(self: @TState) -> bool;
}
