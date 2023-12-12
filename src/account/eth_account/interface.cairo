// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo vX.Y.Z (account/eth_account/interface.cairo)

use openzeppelin::account::interface::{ISRC6, ISRC6CamelOnly, IDeclarer, ISRC6_ID};
use starknet::ContractAddress;
use starknet::account::Call;

type EthPublicKey = (u256, u256);

#[starknet::interface]
trait IDeployable<TState> {
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: EthPublicKey
    ) -> felt252;
}

#[starknet::interface]
trait IPublicKey<TState> {
    fn get_public_key(self: @TState) -> EthPublicKey;
    fn set_public_key(ref self: TState, new_public_key: EthPublicKey);
}


#[starknet::interface]
trait IPublicKeyCamel<TState> {
    fn getPublicKey(self: @TState) -> EthPublicKey;
    fn setPublicKey(ref self: TState, newPublicKey: EthPublicKey);
}

//
// EthAccount ABI
//

#[starknet::interface]
trait EthAccountABI<TState> {
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
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: EthPublicKey
    ) -> felt252;

    // IPublicKey
    fn get_public_key(self: @TState) -> EthPublicKey;
    fn set_public_key(ref self: TState, new_public_key: EthPublicKey);

    // ISRC6CamelOnly
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5Camel
    fn supportsInterface(self: @TState, interfaceId: felt252) -> bool;

    // IPublicKeyCamel
    fn getPublicKey(self: @TState) -> EthPublicKey;
    fn setPublicKey(ref self: TState, newPublicKey: EthPublicKey);
}
