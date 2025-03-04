// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v1.0.0 (account/src/interface.cairo)

use starknet::account::Call;

pub type EthPublicKey = starknet::secp256k1::Secp256k1Point;
pub type P256PublicKey = starknet::secp256r1::Secp256r1Point;

pub const ISRC6_ID: felt252 = 0x2ceccef7f994940b3962a6c67e0ba4fcd37df7d131417c604f91e03caecc1cd;

//
// Account
//

#[starknet::interface]
pub trait ISRC6<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
pub trait IDeclarer<TState> {
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;
}

#[starknet::interface]
pub trait IDeployable<TState> {
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252,
    ) -> felt252;
}

#[starknet::interface]
pub trait IPublicKey<TState> {
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252, signature: Span<felt252>);
}

#[starknet::interface]
pub trait ISRC6CamelOnly<TState> {
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
pub trait IPublicKeyCamel<TState> {
    fn getPublicKey(self: @TState) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252, signature: Span<felt252>);
}

//
// Account ABI
//

#[starknet::interface]
pub trait AccountABI<TState> {
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
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252,
    ) -> felt252;

    // IPublicKey
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252, signature: Span<felt252>);

    // ISRC6CamelOnly
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IPublicKeyCamel
    fn getPublicKey(self: @TState) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252, signature: Span<felt252>);
}

//
// EthAccount
//

#[starknet::interface]
pub trait IEthDeployable<TState> {
    fn __validate_deploy__(
        self: @TState,
        class_hash: felt252,
        contract_address_salt: felt252,
        public_key: EthPublicKey,
    ) -> felt252;
}

#[starknet::interface]
pub trait IEthPublicKey<TState> {
    fn get_public_key(self: @TState) -> EthPublicKey;
    fn set_public_key(ref self: TState, new_public_key: EthPublicKey, signature: Span<felt252>);
}


#[starknet::interface]
pub trait IEthPublicKeyCamel<TState> {
    fn getPublicKey(self: @TState) -> EthPublicKey;
    fn setPublicKey(ref self: TState, newPublicKey: EthPublicKey, signature: Span<felt252>);
}

//
// EthAccount ABI
//

#[starknet::interface]
pub trait EthAccountABI<TState> {
    // ISRC6
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IEthDeployable
    fn __validate_deploy__(
        self: @TState,
        class_hash: felt252,
        contract_address_salt: felt252,
        public_key: EthPublicKey,
    ) -> felt252;

    // IEthPublicKey
    fn get_public_key(self: @TState) -> EthPublicKey;
    fn set_public_key(ref self: TState, new_public_key: EthPublicKey, signature: Span<felt252>);

    // ISRC6CamelOnly
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IEthPublicKeyCamel
    fn getPublicKey(self: @TState) -> EthPublicKey;
    fn setPublicKey(ref self: TState, newPublicKey: EthPublicKey, signature: Span<felt252>);
}
