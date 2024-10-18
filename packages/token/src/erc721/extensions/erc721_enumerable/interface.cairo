// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0
// (token/erc721/extensions/erc721_enumerable/interface.cairo)

use starknet::ContractAddress;

pub const IERC721ENUMERABLE_ID: felt252 =
    0x16bc0f502eeaf65ce0b3acb5eea656e2f26979ce6750e8502a82f377e538c87;

#[starknet::interface]
pub trait IERC721Enumerable<TState> {
    fn total_supply(self: @TState) -> u256;
    fn token_by_index(self: @TState, index: u256) -> u256;
    fn token_of_owner_by_index(self: @TState, owner: ContractAddress, index: u256) -> u256;
}
