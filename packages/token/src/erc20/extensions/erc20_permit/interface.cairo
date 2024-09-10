// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.16.0 (token/erc20/extensions/erc20_permit/interface.cairo)

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20Permit<TState> {
    fn permit(
        ref self: TState,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u64,
        signature: Array<felt252>
    );
    fn nonces(self: @TState, owner: ContractAddress) -> felt252;
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
}

#[starknet::interface]
pub trait ERC20PermitABI<TState> {
    // IERC20
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // IERC20CamelOnly
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;

    // IERC20Metadata
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn decimals(self: @TState) -> u8;

    // IERC20Permit
    fn permit(
        ref self: TState,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u64,
        signature: Array<felt252>
    );
    fn nonces(self: @TState, owner: ContractAddress) -> felt252;
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;

    // ISNIP12Metadata
    fn snip12_metadata(self: @TState) -> (felt252, felt252);
}