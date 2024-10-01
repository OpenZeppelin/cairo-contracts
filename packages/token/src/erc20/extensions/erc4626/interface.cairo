// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (token/erc20/extensions/erc4626/interface.cairo)

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC4626<TState> {
    fn asset(self: @TState) -> ContractAddress;
    fn total_assets(self: @TState) -> u256;
    fn convert_to_shares(self: @TState, assets: u256) -> u256;
    fn convert_to_assets(self: @TState, shares: u256) -> u256;
    fn max_deposit(self: @TState, receiver: ContractAddress) -> u256;
    fn preview_deposit(self: @TState, assets: u256) -> u256;
    fn deposit(ref self: TState, assets: u256, receiver: ContractAddress) -> u256;
    fn max_mint(self: @TState, receiver: ContractAddress) -> u256;
    fn preview_mint(self: @TState, shares: u256) -> u256;
    fn mint(ref self: TState, shares: u256, receiver: ContractAddress) -> u256;
    fn max_withdrawal(self: @TState, owner: ContractAddress) -> u256;
    fn preview_withdrawal(self: @TState, assets: u256) -> u256;
    fn withdraw(
        ref self: TState, assets: u256, receiver: ContractAddress, owner: ContractAddress
    ) -> u256;
    fn max_redeem(self: @TState, owner: ContractAddress) -> u256;
    fn preview_redeem(self: @TState, shares: u256) -> u256;
    fn redeem(
        ref self: TState, shares: u256, receiver: ContractAddress, owner: ContractAddress
    ) -> u256;
}
