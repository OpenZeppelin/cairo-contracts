// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.0 (security/src/interface.cairo)

#[starknet::interface]
pub trait IInitializable<TState> {
    fn is_initialized(self: @TState) -> bool;
}

#[starknet::interface]
pub trait IPausable<TState> {
    fn is_paused(self: @TState) -> bool;
}
