// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.2 (interfaces/src/security/initializable.cairo)

#[starknet::interface]
pub trait IInitializable<TState> {
    fn is_initialized(self: @TState) -> bool;
}
