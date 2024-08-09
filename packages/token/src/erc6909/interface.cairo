// SPDX-License-Identifier: MIT
use starknet::ContractAddress;

// https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC6909.sol
pub const IERC6909_ID: felt252 = 0x32cb2c2fe3eafecaa713aaa072ee54795f66abbd45618bd0ff07284d97116ee;

#[starknet::interface]
pub trait IERC6909<TState> {
    fn balance_of(self: @TState, owner: ContractAddress, id: u256) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress, id: u256) -> u256;
    fn is_operator(self: @TState, owner: ContractAddress, spender: ContractAddress) -> bool;
    fn transfer(ref self: TState, receiver: ContractAddress, id: u256, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, receiver: ContractAddress, id: u256, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, id: u256, amount: u256) -> bool;
    fn set_operator(ref self: TState, spender: ContractAddress, approved: bool) -> bool;
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

// https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC6909Metadata.sol
#[starknet::interface]
pub trait IERC6909Metadata<TState> {
    fn name(self: @TState, id: u256) -> ByteArray;
    fn symbol(self: @TState, id: u256) -> ByteArray;
    fn decimals(self: @TState, id: u256) -> u8;
}

// https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC6909TokenSupply.sol
#[starknet::interface]
pub trait IERC6909TokenSupply<TState> {
    fn total_supply(self: @TState, id: u256) -> u256;
}

//https://github.com/jtriley-eth/ERC-6909/blob/main/src/ERC6909ContentURI.sol
#[starknet::interface]
pub trait IERC6909ContentURI<TState> {
    fn contract_uri(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, id: u256) -> ByteArray;
}
