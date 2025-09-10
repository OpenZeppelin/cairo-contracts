// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.2 (interfaces/src/utils/nonces.cairo)

use starknet::ContractAddress;

#[starknet::interface]
pub trait INonces<TState> {
    fn nonces(self: @TState, owner: ContractAddress) -> felt252;
}
