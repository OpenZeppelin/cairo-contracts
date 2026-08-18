// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (interfaces/src/account/account.cairo)

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
    fn __execute__(self: @TState, calls: Array<Call>);

    /// Validates a transaction before execution.
    /// This function is used by the protocol to verify `invoke` transactions.
    ///
    /// Returns the short string 'VALID' if valid, otherwise it reverts.
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;

    /// Verifies that the given signature is valid for the given hash.
    ///
    /// Returns the short string 'VALID' if valid, otherwise returns 0.
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::interface]
pub trait IDeclarer<TState> {
    /// Validates a transaction before declaration.
    /// This function is used by the protocol to verify `declare` transactions.
    ///
    /// Returns the short string 'VALID' if valid, otherwise it reverts.
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;
}

#[starknet::interface]
pub trait IDeployable<TState> {
    /// Validates a transaction before deployment.
    /// This function is used by the protocol to verify `deploy_account` transactions.
    ///
    /// Returns the short string 'VALID' if valid, otherwise it reverts.
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
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn set_public_key(ref self: TState, new_public_key: felt252, signature: Span<felt252>);
}

/// Adds camelCase support for `ISRC6`.
#[starknet::interface]
pub trait ISRC6CamelOnly<TState> {
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

/// Adds camelCase support for `IPublicKey`.
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
    fn __execute__(self: @TState, calls: Array<Call>);
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
// MultisigAccount
//

/// Interface for managing the signer set and quorum of a multisig account.
#[starknet::interface]
pub trait IMultisigAccount<TState> {
    /// Returns the minimum number of signer records required to authorize an operation.
    fn get_quorum(self: @TState) -> u32;

    /// Returns whether `signer` is registered as a signer public key.
    fn is_signer(self: @TState, signer: felt252) -> bool;

    /// Returns all registered signer public keys in registry order.
    /// Registry order is not sorted and can change when signers are removed.
    fn get_signers(self: @TState) -> Span<felt252>;

    /// Adds signer public keys and sets the quorum to `new_quorum`.
    /// Already registered public keys are ignored.
    fn add_signers(ref self: TState, new_quorum: u32, signers_to_add: Span<felt252>);

    /// Removes signer public keys and sets the quorum to `new_quorum`.
    /// Unregistered public keys are ignored. Removing signers can change registry order.
    fn remove_signers(ref self: TState, new_quorum: u32, signers_to_remove: Span<felt252>);

    /// Replaces one signer public key with another.
    fn replace_signer(ref self: TState, signer_to_remove: felt252, signer_to_add: felt252);

    /// Sets the number of signer records required to authorize an operation.
    fn change_quorum(ref self: TState, new_quorum: u32);
}

/// Validates a transaction before deploying a multisig account.
#[starknet::interface]
pub trait IMultisigDeployable<TState> {
    /// This function is used by the protocol to verify `deploy_account` transactions whose
    /// constructor configures a signer set and quorum.
    ///
    /// Returns the short string 'VALID' if valid, otherwise it reverts.
    fn __validate_deploy__(
        self: @TState,
        class_hash: felt252,
        contract_address_salt: felt252,
        quorum: u32,
        signers: Span<felt252>,
    ) -> felt252;
}

/// Complete ABI for a Stark-curve multisig account.
#[starknet::interface]
pub trait MultisigAccountABI<TState> {
    // ISRC6
    fn __execute__(self: @TState, calls: Array<Call>);
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IMultisigDeployable
    fn __validate_deploy__(
        self: @TState,
        class_hash: felt252,
        contract_address_salt: felt252,
        quorum: u32,
        signers: Span<felt252>,
    ) -> felt252;

    // IMultisigAccount
    fn get_quorum(self: @TState) -> u32;
    fn is_signer(self: @TState, signer: felt252) -> bool;
    fn get_signers(self: @TState) -> Span<felt252>;
    fn add_signers(ref self: TState, new_quorum: u32, signers_to_add: Span<felt252>);
    fn remove_signers(ref self: TState, new_quorum: u32, signers_to_remove: Span<felt252>);
    fn replace_signer(ref self: TState, signer_to_remove: felt252, signer_to_add: felt252);
    fn change_quorum(ref self: TState, new_quorum: u32);

    // ISRC6CamelOnly
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

//
// EthAccount
//

#[starknet::interface]
pub trait IEthDeployable<TState> {
    /// Validates a transaction before deployment.
    /// This function is used by the protocol to verify `deploy_account` transactions.
    ///
    /// Returns the short string 'VALID' if valid, otherwise it reverts.
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
    /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
    fn set_public_key(ref self: TState, new_public_key: EthPublicKey, signature: Span<felt252>);
}

/// Adds camelCase support for `IEthPublicKey`.
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
    fn __execute__(self: @TState, calls: Array<Call>);
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
