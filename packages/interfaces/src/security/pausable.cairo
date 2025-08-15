// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.1 (interfaces/src/security/pausable.cairo)

#[starknet::interface]
pub trait IPausable<TState> {
    fn is_paused(self: @TState) -> bool;
}
