// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (token/common/erc2981/interface.cairo)

use starknet::ContractAddress;

pub const IERC2981_ID: felt252 = 0x2d3414e45a8700c29f119a54b9f11dca0e29e06ddcb214018fc37340e165ed6;

#[starknet::interface]
pub trait IERC2981<TState> {
    /// Returns how much royalty is owed and to whom, based on a sale price that may be denominated
    /// in any unit of exchange. The royalty amount is denominated and should be paid in that same
    /// unit of exchange.
    fn royalty_info(self: @TState, token_id: u256, sale_price: u256) -> (ContractAddress, u256);
}

#[starknet::interface]
pub trait IERC2981StateInfo<TState> {
    fn default_royalty(self: @TState) -> (ContractAddress, u128, u128);
    fn token_royalty(self: @TState, token_id: u256) -> (ContractAddress, u128, u128);
}

#[starknet::interface]
pub trait IERC2981Admin<TState> {
    fn set_default_royalty(ref self: TState, receiver: ContractAddress, fee_numerator: u128,);
    fn delete_default_royalty(ref self: TState);
    fn set_token_royalty(
        ref self: TState, token_id: u256, receiver: ContractAddress, fee_numerator: u128
    );
    fn reset_token_royalty(ref self: TState, token_id: u256);
}

#[starknet::interface]
pub trait IERC2981ABI<TState> {
    // IERC2981
    fn royalty_info(self: @TState, token_id: u256, sale_price: u256) -> (ContractAddress, u256);

    // IERC2981StateInfo
    fn default_royalty(self: @TState) -> (ContractAddress, u128, u128);
    fn token_royalty(self: @TState, token_id: u256) -> (ContractAddress, u128, u128);

    // IERC2981Admin
    fn set_default_royalty(ref self: TState, receiver: ContractAddress, fee_numerator: u128,);
    fn delete_default_royalty(ref self: TState);
    fn set_token_royalty(
        ref self: TState, token_id: u256, receiver: ContractAddress, fee_numerator: u128
    );
    fn reset_token_royalty(ref self: TState, token_id: u256);
}
