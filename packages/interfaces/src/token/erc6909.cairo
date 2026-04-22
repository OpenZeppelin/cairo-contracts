// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (interfaces/src/token/erc6909.cairo)

use starknet::ContractAddress;

pub const IERC6909_ID: felt252 = 0xd5aa138060489fd9c4592f77a16011cc5615ce4d292ee1f7873ae65c43b6bb;
pub const IERC6909_METADATA_ID: felt252 =
    0x19aa0b778d120d5294054319458ee8886514766411c50dceddd9463712d6011;
pub const IERC6909_TOKEN_SUPPLY_ID: felt252 =
    0x3a632c15cb93b574eb9166de70521abbeab5c2eb4fdab9930729bba8658c41;
pub const IERC6909_CONTENT_URI_ID: felt252 =
    0x356efd8b40a01c1525c7d0ecafbe3b82a47df564fdd496727effe6336526f05;

#[starknet::interface]
pub trait IERC6909<TState> {
    fn balance_of(self: @TState, owner: ContractAddress, id: u256) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress, id: u256) -> u256;
    fn is_operator(self: @TState, owner: ContractAddress, spender: ContractAddress) -> bool;
    fn transfer(ref self: TState, receiver: ContractAddress, id: u256, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState,
        sender: ContractAddress,
        receiver: ContractAddress,
        id: u256,
        amount: u256,
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, id: u256, amount: u256) -> bool;
    fn set_operator(ref self: TState, spender: ContractAddress, approved: bool) -> bool;
}

#[starknet::interface]
pub trait ERC6909ABI<TState> {
    // IERC6909
    fn balance_of(self: @TState, owner: ContractAddress, id: u256) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress, id: u256) -> u256;
    fn is_operator(self: @TState, owner: ContractAddress, spender: ContractAddress) -> bool;
    fn transfer(ref self: TState, receiver: ContractAddress, id: u256, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState,
        sender: ContractAddress,
        receiver: ContractAddress,
        id: u256,
        amount: u256,
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, id: u256, amount: u256) -> bool;
    fn set_operator(ref self: TState, spender: ContractAddress, approved: bool) -> bool;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IERC6909Metadata
    fn name(self: @TState, id: u256) -> ByteArray;
    fn symbol(self: @TState, id: u256) -> ByteArray;
    fn decimals(self: @TState, id: u256) -> u8;

    // IERC6909MetadataAdmin
    fn set_token_name(ref self: TState, id: u256, name: ByteArray);
    fn set_token_symbol(ref self: TState, id: u256, symbol: ByteArray);
    fn set_token_decimals(ref self: TState, id: u256, decimals: u8);

    // IERC6909TokenSupply
    fn total_supply(self: @TState, id: u256) -> u256;

    // IERC6909ContentUri
    fn contract_uri(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, id: u256) -> ByteArray;

    // IERC6909ContentUriAdmin
    fn set_contract_uri(ref self: TState, contract_uri: ByteArray);
    fn set_token_uri(ref self: TState, id: u256, token_uri: ByteArray);
}

//
// ERC6909Metadata
//

#[starknet::interface]
pub trait IERC6909Metadata<TState> {
    fn name(self: @TState, id: u256) -> ByteArray;
    fn symbol(self: @TState, id: u256) -> ByteArray;
    fn decimals(self: @TState, id: u256) -> u8;
}

/// Interface providing external admin functions for managing the metadata of ERC6909 component.
#[starknet::interface]
pub trait IERC6909MetadataAdmin<TState> {
    /// Sets the name for the token of type `id`.
    fn set_token_name(ref self: TState, id: u256, name: ByteArray);

    /// Sets the symbol for the token of type `id`.
    fn set_token_symbol(ref self: TState, id: u256, symbol: ByteArray);

    /// Sets the decimals for the token of type `id`.
    fn set_token_decimals(ref self: TState, id: u256, decimals: u8);
}

//
// ERC6909TokenSupply
//

#[starknet::interface]
pub trait IERC6909TokenSupply<TState> {
    fn total_supply(self: @TState, id: u256) -> u256;
}

//
// ERC6909ContentURI
//

#[starknet::interface]
pub trait IERC6909ContentUri<TState> {
    fn contract_uri(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, id: u256) -> ByteArray;
}

/// Interface providing external admin functions for managing the content URIs of ERC6909 component.
#[starknet::interface]
pub trait IERC6909ContentUriAdmin<TState> {
    /// Sets the contract-level URI.
    fn set_contract_uri(ref self: TState, contract_uri: ByteArray);

    /// Sets the URI for the token of type `id`.
    fn set_token_uri(ref self: TState, id: u256, token_uri: ByteArray);
}
