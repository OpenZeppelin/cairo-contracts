// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v1.0.0 (token/src/erc20/interface.cairo)

use starknet::ContractAddress;

/// Interface of the ERC20 standard as defined in the EIP.
#[starknet::interface]
pub trait IERC20<TState> {
    /// Returns the total supply of tokens.
    fn total_supply(self: @TState) -> u256;

    /// Returns the amount of tokens owned by `account`.
    fn balance_of(self: @TState, account: ContractAddress) -> u256;

    /// Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through `transfer_from`.
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Moves `amount` tokens from the caller's account to `recipient`.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;

    /// Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;

    /// Sets `amount` as the allowance of `spender` over the caller's tokens.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

/// Interface for the optional metadata functions.
#[starknet::interface]
pub trait IERC20Metadata<TState> {
    /// Returns the name of the token.
    fn name(self: @TState) -> ByteArray;

    /// Returns the symbol of the token.
    fn symbol(self: @TState) -> ByteArray;

    /// Returns the number of decimals used to get its user representation.
    fn decimals(self: @TState) -> u8;
}

/// Interface for the camelCase version of ERC20 functions.
#[starknet::interface]
pub trait IERC20Camel<TState> {
    /// Returns the total supply of tokens.
    fn totalSupply(self: @TState) -> u256;

    /// Returns the amount of tokens owned by `account`.
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;

    /// Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through `transferFrom`.
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Moves `amount` tokens from the caller's account to `recipient`.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;

    /// Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;

    /// Sets `amount` as the allowance of `spender` over the caller's tokens.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

/// Interface for the camelCase version of ERC20 functions without the approve function.
#[starknet::interface]
pub trait IERC20CamelOnly<TState> {
    /// Returns the total supply of tokens.
    fn totalSupply(self: @TState) -> u256;

    /// Returns the amount of tokens owned by `account`.
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;

    /// Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
}

/// Interface that combines IERC20, IERC20Metadata, and IERC20CamelOnly.
#[starknet::interface]
pub trait IERC20Mixin<TState> {
    // IERC20
    /// Returns the total supply of tokens.
    fn total_supply(self: @TState) -> u256;

    /// Returns the amount of tokens owned by `account`.
    fn balance_of(self: @TState, account: ContractAddress) -> u256;

    /// Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through `transfer_from`.
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Moves `amount` tokens from the caller's account to `recipient`.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;

    /// Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;

    /// Sets `amount` as the allowance of `spender` over the caller's tokens.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // IERC20Metadata
    /// Returns the name of the token.
    fn name(self: @TState) -> ByteArray;

    /// Returns the symbol of the token.
    fn symbol(self: @TState) -> ByteArray;

    /// Returns the number of decimals used to get its user representation.
    fn decimals(self: @TState) -> u8;

    // IERC20CamelOnly
    /// Returns the total supply of tokens.
    fn totalSupply(self: @TState) -> u256;

    /// Returns the amount of tokens owned by `account`.
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;

    /// Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
}

/// Interface for the ERC20 permit extension.
#[starknet::interface]
pub trait IERC20Permit<TState> {
    /// Sets `amount` as the allowance of `spender` over `owner`'s tokens, given the `signature`.
    ///
    /// Requirements:
    ///
    /// - `deadline` must be a timestamp in the future.
    /// - `signature` must be a valid secp256k1 signature from `owner` over the EIP712-formatted
    ///   function arguments.
    fn permit(
        ref self: TState,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u64,
        signature: Span<felt252>,
    );

    /// Returns the current nonce for `owner`.
    fn nonces(self: @TState, owner: ContractAddress) -> felt252;

    /// Returns the domain separator used in the encoding of the signatures for permit.
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
}

/// Interface that combines all ERC20 interfaces including permit and metadata.
#[starknet::interface]
pub trait ERC20ABI<TState> {
    // IERC20
    /// Returns the total supply of tokens.
    fn total_supply(self: @TState) -> u256;

    /// Returns the amount of tokens owned by `account`.
    fn balance_of(self: @TState, account: ContractAddress) -> u256;

    /// Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through `transfer_from`.
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Moves `amount` tokens from the caller's account to `recipient`.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;

    /// Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;

    /// Sets `amount` as the allowance of `spender` over the caller's tokens.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // IERC20Metadata
    /// Returns the name of the token.
    fn name(self: @TState) -> ByteArray;

    /// Returns the symbol of the token.
    fn symbol(self: @TState) -> ByteArray;

    /// Returns the number of decimals used to get its user representation.
    fn decimals(self: @TState) -> u8;

    // IERC20CamelOnly
    /// Returns the total supply of tokens.
    fn totalSupply(self: @TState) -> u256;

    /// Returns the amount of tokens owned by `account`.
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;

    /// Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    ///
    /// Returns a boolean value indicating whether the operation succeeded.
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;

    // IERC20Permit
    /// Sets `amount` as the allowance of `spender` over `owner`'s tokens, given the `signature`.
    ///
    /// Requirements:
    ///
    /// - `deadline` must be a timestamp in the future.
    /// - `signature` must be a valid secp256k1 signature from `owner` over the EIP712-formatted
    ///   function arguments.
    fn permit(
        ref self: TState,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u64,
        signature: Span<felt252>,
    );

    /// Returns the current nonce for `owner`.
    fn nonces(self: @TState, owner: ContractAddress) -> felt252;

    /// Returns the domain separator used in the encoding of the signatures for permit.
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;

    // ISNIP12Metadata
    /// Returns the metadata of the token as defined in SNIP-12.
    fn snip12_metadata(self: @TState) -> (felt252, felt252);
}
