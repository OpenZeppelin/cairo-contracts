// SPDX-License-Identifier: MIT
use starknet::ContractAddress;

// https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC6909.sol
pub const IERC6909_ID: felt252 = 0x32cb2c2fe3eafecaa713aaa072ee54795f66abbd45618bd0ff07284d97116ee;

#[starknet::interface]
pub trait IERC6909<TState> {
    /// @notice Owner balance of an id.
    /// @param owner The address of the owner.
    /// @param id The id of the token.
    /// @return The balance of the token.
    fn balance_of(self: @TState, owner: ContractAddress, id: u256) -> u256;

    /// @notice Spender allowance of an id.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param id The id of the token.
    /// @return The allowance of the token.
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress, id: u256) -> u256;

    /// @notice Checks if a spender is approved by an owner as an operator
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @return The approval status.
    fn is_operator(self: @TState, owner: ContractAddress, spender: ContractAddress) -> bool;

    /// @notice Transfers an amount of an id from the caller to a receiver.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    fn transfer(ref self: TState, receiver: ContractAddress, id: u256, amount: u256) -> bool;

    /// @notice Transfers an amount of an id from a sender to a receiver.
    /// @param sender The address of the sender.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    fn transfer_from(
        ref self: TState, sender: ContractAddress, receiver: ContractAddress, id: u256, amount: u256
    ) -> bool;

    /// @notice Approves an amount of an id to a spender.
    /// @param spender The address of the spender.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    fn approve(ref self: TState, spender: ContractAddress, id: u256, amount: u256) -> bool;

    /// @notice Sets or removes a spender as an operator for the caller.
    /// @param spender The address of the spender.
    /// @param approved The approval status.
    fn set_operator(ref self: TState, spender: ContractAddress, approved: bool) -> bool;

    // https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC165.sol
    /// @notice Checks if a contract implements an interface.
    /// @param interfaceId The interface identifier, as specified in ERC-165.
    /// @return True if the contract implements `interfaceId` and
    /// `interfaceId` is not 0xffffffff, false otherwise.
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::interface]
pub trait IERC6909Camel<TState> {
    /// @notice Owner balance of an id.
    /// @param owner The address of the owner.
    /// @param id The id of the token.
    /// @return The balance of the token.
    fn balanceOf(self: @TState, owner: ContractAddress, id: u256) -> u256;

    /// @notice Spender allowance of an id.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param id The id of the token.
    /// @return The allowance of the token.
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress, id: u256) -> u256;

    /// @notice Checks if a spender is approved by an owner as an operator
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @return The approval status.
    fn isOperator(self: @TState, owner: ContractAddress, spender: ContractAddress) -> bool;

    /// @notice Transfers an amount of an id from the caller to a receiver.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    fn transfer(ref self: TState, receiver: ContractAddress, id: u256, amount: u256) -> bool;

    /// @notice Transfers an amount of an id from a sender to a receiver.
    /// @param sender The address of the sender.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    fn transferFrom(
        ref self: TState, sender: ContractAddress, receiver: ContractAddress, id: u256, amount: u256
    ) -> bool;

    /// @notice Approves an amount of an id to a spender.
    /// @param spender The address of the spender.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    fn approve(ref self: TState, spender: ContractAddress, id: u256, amount: u256) -> bool;

    /// @notice Sets or removes a spender as an operator for the caller.
    /// @param spender The address of the spender.
    /// @param approved The approval status.
    fn setOperator(ref self: TState, spender: ContractAddress, approved: bool) -> bool;

    // https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC165.sol
    /// @notice Checks if a contract implements an interface.
    /// @param interfaceId The interface identifier, as specified in ERC-165.
    /// @return True if the contract implements `interfaceId` and
    /// `interfaceId` is not 0xffffffff, false otherwise.
    fn supportsInterface(self: @TState, interface_id: felt252) -> bool;
}


#[starknet::interface]
pub trait IERC6909CamelOnly<TState> {
    /// @notice Owner balance of an id.
    /// @param owner The address of the owner.
    /// @param id The id of the token.
    /// @return The balance of the token.
    fn balanceOf(self: @TState, owner: ContractAddress, id: u256) -> u256;

    /// @notice Checks if a spender is approved by an owner as an operator
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @return The approval status.
    fn isOperator(self: @TState, owner: ContractAddress, spender: ContractAddress) -> bool;

    /// @notice Transfers an amount of an id from a sender to a receiver.
    /// @param sender The address of the sender.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    fn transferFrom(
        ref self: TState, sender: ContractAddress, receiver: ContractAddress, id: u256, amount: u256
    ) -> bool;

    /// @notice Sets or removes a spender as an operator for the caller.
    /// @param spender The address of the spender.
    /// @param approved The approval status.
    fn setOperator(ref self: TState, spender: ContractAddress, approved: bool) -> bool;

    // https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC165.sol
    /// @notice Checks if a contract implements an interface.
    /// @param interfaceId The interface identifier, as specified in ERC-165.
    /// @return True if the contract implements `interfaceId` and
    /// `interfaceId` is not 0xffffffff, false otherwise.
    fn supportsInterface(self: @TState, interface_id: felt252) -> bool;
}

// https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC6909Metadata.sol
#[starknet::interface]
pub trait IERC6909Metadata<TState> {
    /// @notice Name of a given token.
    /// @param id The id of the token.
    /// @return The name of the token.
    fn name(self: @TState, id: u256) -> ByteArray;

    /// @notice Symbol of a given token.
    /// @param id The id of the token.
    /// @return The symbol of the token.
    fn symbol(self: @TState, id: u256) -> ByteArray;

    /// @notice Decimals of a given token.
    /// @param id The id of the token.
    /// @return The decimals of the token.
    fn decimals(self: @TState, id: u256) -> u8;
}

// https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC6909TokenSupply.sol
#[starknet::interface]
pub trait IERC6909TokenSupply<TState> {
    /// @notice Total supply of a token
    /// @param id The id of the token.
    /// @return The total supply of the token.
    fn total_supply(self: @TState, id: u256) -> u256;
}

#[starknet::interface]
pub trait IERC6909TokenSupplyCamel<TState> {
    /// @notice Total supply of a token
    /// @param id The id of the token.
    /// @return The total supply of the token.
    fn totalSupply(self: @TState, id: u256) -> u256;
}

//https://github.com/jtriley-eth/ERC-6909/blob/main/src/ERC6909ContentURI.sol
#[starknet::interface]
pub trait IERC6909ContentURI<TState> {
    /// @notice Contract level URI
    /// @return The contract level URI.
    fn contract_uri(self: @TState) -> ByteArray;

    /// @notice Token level URI
    /// @param id The id of the token.
    /// @return The token level URI.
    fn token_uri(self: @TState, id: u256) -> ByteArray;
}

#[starknet::interface]
pub trait IERC6909ContentURICamel<TState> {
    /// @notice Contract level URI
    /// @return The contract level URI.
    fn contractUri(self: @TState) -> ByteArray;

    /// @notice Token level URI
    /// @param id The id of the token.
    /// @return The token level URI.
    fn tokenUri(self: @TState, id: u256) -> ByteArray;
}

// https://github.com/jtriley-eth/ERC-6909/blob/main/src/interfaces/IERC6909.sol
#[starknet::interface]
pub trait ERC6909ABI<TState> {
    /// @notice IERC6909 standard interface
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

    /// @notice IERC6909Camel
    fn balanceOf(self: @TState, owner: ContractAddress, id: u256) -> u256;
    fn isOperator(self: @TState, owner: ContractAddress, spender: ContractAddress) -> bool;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, receiver: ContractAddress, id: u256, amount: u256
    ) -> bool;
    fn setOperator(ref self: TState, spender: ContractAddress, approved: bool) -> bool;
    fn supportsInterface(self: @TState, interfaceId: felt252) -> bool;
}
