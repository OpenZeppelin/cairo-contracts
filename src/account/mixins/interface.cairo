// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (account/mixins/interface.cairo)

use starknet::ContractAddress;
use starknet::account::Call;

//
// Mixins
//

#[starknet::interface]
trait ISRC6Mixin<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
trait ISRC6DeclarerMixin<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;
}

#[starknet::interface]
trait ISRC6DeployerMixin<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IDeployer
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252
    ) -> felt252;
}

#[starknet::interface]
trait ISRC6DeclarerDeployerMixin<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IDeployer
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252
    ) -> felt252;
}

#[starknet::interface]
trait ISRC6PubKeyMixin<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IPublicKey
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252);

    // IPublicKeyCamel
    fn getPublicKey(self: @TState) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252);
}

#[starknet::interface]
trait ISRC6PubKeyDeployerMixin<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IDeployer
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252
    ) -> felt252;

    // IPublicKey
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252);

    // IPublicKeyCamel
    fn getPublicKey(self: @TState) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252);
}

#[starknet::interface]
trait ISRC6PubKeyDeclarerMixin<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IPublicKey
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252);

    // IPublicKeyCamel
    fn getPublicKey(self: @TState) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252);
}

#[starknet::interface]
trait ISRC6PubKeyDeclarerDeployerMixin<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IDeployer
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252
    ) -> felt252;

    // IPublicKey
    fn get_public_key(self: @TState) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252);

    // IPublicKeyCamel
    fn getPublicKey(self: @TState) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252);
}
