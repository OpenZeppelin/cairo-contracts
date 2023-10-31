// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.0 (account/interface.cairo)

use starknet::ContractAddress;
use starknet::account::Call;

const ISRC6_ID: felt252 = 0x2ceccef7f994940b3962a6c67e0ba4fcd37df7d131417c604f91e03caecc1cd;

#[starknet::interface]
trait ISRC6<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
trait ISRC6CamelOnly<TState> {
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
trait IDeclarer<TState> {
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;
}

#[starknet::interface]
trait IDeployable<TState> {
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252
    ) -> felt252;
}

#[starknet::interface]
trait IPublicKey<TState> {
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252);
}

#[starknet::interface]
trait IPublicKeyCamel<TState> {
    fn getPublicKey(self: @TState) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252);
}

//
// Account ABI
//

#[starknet::interface]
trait AccountABI<TState> {
    // ISRC6
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IDeployable
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252
    ) -> felt252;

    // IPublicKey
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252);

    // ISRC6CamelOnly
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5Camel
    fn supportsInterface(self: @TState, interfaceId: felt252) -> bool;

    // IPublicKeyCamel
    fn getPublicKey(self: @TState) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252);
}
