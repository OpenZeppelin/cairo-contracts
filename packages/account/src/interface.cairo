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
    /// Executes a list of calls from the account.
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;

    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `invoke` transactions.
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;

    /// Verifies that the given signature is valid for the given hash.
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
pub trait IDeclarer<TState> {
    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `declare` transactions.
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;
}

#[starknet::interface]
pub trait IDeployable<TState> {
    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `deploy_account` transactions.
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252,
    ) -> felt252;
}

#[starknet::interface]
pub trait IPublicKey<TState> {
    /// Returns the current public key of the account.
    fn get_public_key(self: @TState) -> felt252;

    /// Sets the public key of the account to `new_public_key`.
    ///
    /// Requirements:
    ///
    /// - The caller must be the contract itself.
    /// - The signature must be valid for the new owner.
    ///
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn set_public_key(ref self: TState, new_public_key: felt252, signature: Span<felt252>);
}

#[starknet::interface]
pub trait ISRC6CamelOnly<TState> {
    /// Verifies that the given signature is valid for the given hash.
    /// This is a camelCase version of `is_valid_signature` for compatibility.
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
pub trait IPublicKeyCamel<TState> {
    /// Returns the current public key of the account.
    /// This is a camelCase version of `get_public_key` for compatibility.
    fn getPublicKey(self: @TState) -> felt252;

    /// Sets the public key of the account to `newPublicKey`.
    /// This is a camelCase version of `set_public_key` for compatibility.
    ///
    /// Requirements:
    ///
    /// - The caller must be the contract itself.
    /// - The signature must be valid for the new owner.
    ///
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn setPublicKey(ref self: TState, newPublicKey: felt252, signature: Span<felt252>);
}

//
// Account ABI
//

#[starknet::interface]
pub trait AccountABI<TState> {
    // ISRC6
    /// Executes a list of calls from the account.
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;

    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `invoke` transactions.
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;

    /// Verifies that the given signature is valid for the given hash.
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5
    /// Returns true if the contract implements the interface defined by `interface_id`.
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IDeclarer
    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `declare` transactions.
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IDeployable
    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `deploy_account` transactions.
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: felt252,
    ) -> felt252;

    // IPublicKey
    /// Returns the current public key of the account.
    fn get_public_key(self: @TState) -> felt252;

    /// Sets the public key of the account to `new_public_key`.
    ///
    /// Requirements:
    ///
    /// - The caller must be the contract itself.
    /// - The signature must be valid for the new owner.
    ///
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn set_public_key(ref self: TState, new_public_key: felt252, signature: Span<felt252>);

    // ISRC6CamelOnly
    /// Verifies that the given signature is valid for the given hash.
    /// This is a camelCase version of `is_valid_signature` for compatibility.
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IPublicKeyCamel
    /// Returns the current public key of the account.
    /// This is a camelCase version of `get_public_key` for compatibility.
    fn getPublicKey(self: @TState) -> felt252;

    /// Sets the public key of the account to `newPublicKey`.
    /// This is a camelCase version of `set_public_key` for compatibility.
    ///
    /// Requirements:
    ///
    /// - The caller must be the contract itself.
    /// - The signature must be valid for the new owner.
    ///
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn setPublicKey(ref self: TState, newPublicKey: felt252, signature: Span<felt252>);
}

//
// EthAccount
//

#[starknet::interface]
pub trait IEthDeployable<TState> {
    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `deploy_account` transactions.
    fn __validate_deploy__(
        self: @TState,
        class_hash: felt252,
        contract_address_salt: felt252,
        public_key: EthPublicKey,
    ) -> felt252;
}

#[starknet::interface]
pub trait IEthPublicKey<TState> {
    /// Returns the current Ethereum public key of the account.
    fn get_public_key(self: @TState) -> EthPublicKey;

    /// Sets the Ethereum public key of the account to `new_public_key`.
    ///
    /// Requirements:
    ///
    /// - The caller must be the contract itself.
    /// - The signature must be valid for the new owner.
    ///
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn set_public_key(ref self: TState, new_public_key: EthPublicKey, signature: Span<felt252>);
}

#[starknet::interface]
pub trait IEthPublicKeyCamel<TState> {
    /// Returns the current Ethereum public key of the account.
    /// This is a camelCase version of `get_public_key` for compatibility.
    fn getPublicKey(self: @TState) -> EthPublicKey;

    /// Sets the Ethereum public key of the account to `newPublicKey`.
    /// This is a camelCase version of `set_public_key` for compatibility.
    ///
    /// Requirements:
    ///
    /// - The caller must be the contract itself.
    /// - The signature must be valid for the new owner.
    ///
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn setPublicKey(ref self: TState, newPublicKey: EthPublicKey, signature: Span<felt252>);
}

//
// EthAccount ABI
//

#[starknet::interface]
pub trait EthAccountABI<TState> {
    // ISRC6
    /// Executes a list of calls from the account.
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;

    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `invoke` transactions.
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;

    /// Verifies that the given signature is valid for the given hash.
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5
    /// Returns true if the contract implements the interface defined by `interface_id`.
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IDeclarer
    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `declare` transactions.
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IEthDeployable
    /// Verifies the validity of the signature for the current transaction.
    /// This function is used by the protocol to verify `deploy_account` transactions.
    fn __validate_deploy__(
        self: @TState,
        class_hash: felt252,
        contract_address_salt: felt252,
        public_key: EthPublicKey,
    ) -> felt252;

    // IEthPublicKey
    /// Returns the current Ethereum public key of the account.
    fn get_public_key(self: @TState) -> EthPublicKey;

    /// Sets the Ethereum public key of the account to `new_public_key`.
    ///
    /// Requirements:
    ///
    /// - The caller must be the contract itself.
    /// - The signature must be valid for the new owner.
    ///
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn set_public_key(ref self: TState, new_public_key: EthPublicKey, signature: Span<felt252>);

    // ISRC6CamelOnly
    /// Verifies that the given signature is valid for the given hash.
    /// This is a camelCase version of `is_valid_signature` for compatibility.
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IEthPublicKeyCamel
    /// Returns the current Ethereum public key of the account.
    /// This is a camelCase version of `get_public_key` for compatibility.
    fn getPublicKey(self: @TState) -> EthPublicKey;

    /// Sets the Ethereum public key of the account to `newPublicKey`.
    /// This is a camelCase version of `set_public_key` for compatibility.
    ///
    /// Requirements:
    ///
    /// - The caller must be the contract itself.
    /// - The signature must be valid for the new owner.
    ///
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn setPublicKey(ref self: TState, newPublicKey: EthPublicKey, signature: Span<felt252>);
}
