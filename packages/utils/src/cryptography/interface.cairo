// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (utils/cryptography/interface.cairo)

use starknet::ContractAddress;

#[starknet::interface]
pub trait INonces<TState> {
    fn nonces(self: @TState, owner: ContractAddress) -> felt252;
}
