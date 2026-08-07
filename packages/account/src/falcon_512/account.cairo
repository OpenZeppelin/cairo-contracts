// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/account.cairo)

//! Shared account component for the Falcon-512 SHAKE account contracts.

/// Verification surface implemented by each Falcon-512 account variant.
pub(crate) trait Falcon512SignatureVerifier {
    /// Returns whether `signature` authenticates `message_hash` under `public_key`.
    fn verify(message_hash: felt252, public_key: Span<felt252>, signature: Span<felt252>) -> bool;

    /// Returns whether the packed public key has the required canonical encoding.
    fn is_valid_public_key(public_key: Span<felt252>) -> bool;
}

/// Account component for array-encoded Falcon-512 public keys.
#[starknet::component]
pub(crate) mod Falcon512AccountComponent {
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::num::traits::Zero;
    use core::poseidon::{PoseidonTrait, poseidon_hash_span};
    use openzeppelin_interfaces::accounts as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use openzeppelin_utils::execution::execute_single_call;
    use starknet::account::Call;
    use starknet::storage::{
        MutableVecTrait, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use crate::utils::is_tx_version_valid;
    use super::Falcon512SignatureVerifier;

    #[storage]
    pub struct Storage {
        pub public_key: Vec<felt252>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        OwnerAdded: OwnerAdded,
        OwnerRemoved: OwnerRemoved,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct OwnerAdded {
        #[key]
        pub new_owner_guid: felt252,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct OwnerRemoved {
        #[key]
        pub removed_owner_guid: felt252,
    }

    pub mod Errors {
        pub const INVALID_CALLER: felt252 = 'Account: invalid caller';
        pub const INVALID_PUBLIC_KEY: felt252 = 'Account: invalid public key';
        pub const INVALID_SIGNATURE: felt252 = 'Account: invalid signature';
        pub const INVALID_TX_VERSION: felt252 = 'Account: invalid tx version';
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
    }

    #[embeddable_as(SRC6Impl)]
    impl SRC6<
        TContractState,
        impl Verifier: Falcon512SignatureVerifier,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::ISRC6<ComponentState<TContractState>> {
        /// Executes calls forwarded by the account after protocol validation succeeds.
        fn __execute__(self: @ComponentState<TContractState>, calls: Array<Call>) {
            let sender = starknet::get_caller_address();
            assert(sender.is_zero(), Errors::INVALID_CALLER);
            assert(is_tx_version_valid(), Errors::INVALID_TX_VERSION);

            for call in calls.span() {
                execute_single_call(call);
            }
        }

        /// Validates an invoke transaction with the current transaction signature.
        fn __validate__(self: @ComponentState<TContractState>, calls: Array<Call>) -> felt252 {
            let _ = calls;
            self.validate_transaction::<Verifier>()
        }

        /// Verifies a signature for an arbitrary message hash.
        fn is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>,
        ) -> felt252 {
            if Verifier::verify(hash, self.read_public_key().span(), signature.span()) {
                starknet::VALIDATED
            } else {
                0
            }
        }
    }

    #[embeddable_as(DeclarerImpl)]
    impl Declarer<
        TContractState,
        impl Verifier: Falcon512SignatureVerifier,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IDeclarer<ComponentState<TContractState>> {
        /// Validates a declare transaction with the current transaction signature.
        fn __validate_declare__(
            self: @ComponentState<TContractState>, class_hash: felt252,
        ) -> felt252 {
            let _ = class_hash;
            self.validate_transaction::<Verifier>()
        }
    }

    #[embeddable_as(DeployableImpl)]
    impl Deployable<
        TContractState,
        impl Verifier: Falcon512SignatureVerifier,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IFeltArrayDeployable<ComponentState<TContractState>> {
        /// Validates a deploy-account transaction with the current transaction signature.
        fn __validate_deploy__(
            self: @ComponentState<TContractState>,
            class_hash: felt252,
            contract_address_salt: felt252,
            public_key: Array<felt252>,
        ) -> felt252 {
            let _ = class_hash;
            let _ = contract_address_salt;
            let _ = public_key;
            self.validate_transaction::<Verifier>()
        }
    }

    #[embeddable_as(PublicKeyImpl)]
    impl PublicKey<
        TContractState,
        impl Verifier: Falcon512SignatureVerifier,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IFeltArrayPublicKey<ComponentState<TContractState>> {
        /// Returns the current packed Falcon-512 public key.
        fn get_public_key(self: @ComponentState<TContractState>) -> Array<felt252> {
            self.read_public_key()
        }

        /// Sets the public key to a canonical packed Falcon-512 public key.
        ///
        /// Requirements:
        ///
        /// - The caller must be the contract itself.
        /// - The new public key must use the canonical 29-felt encoding.
        /// - The signature must prove acceptance by the new owner.
        ///
        /// Emits both an `OwnerRemoved` and an `OwnerAdded` event.
        fn set_public_key(
            ref self: ComponentState<TContractState>,
            new_public_key: Array<felt252>,
            signature: Span<felt252>,
        ) {
            self.assert_only_self();
            assert(
                Verifier::is_valid_public_key(new_public_key.span()), Errors::INVALID_PUBLIC_KEY,
            );

            let current_public_key = self.read_public_key();
            let removed_owner_guid = poseidon_hash_span(current_public_key.span());
            let current_owner = current_public_key.span();
            let new_owner = new_public_key.span();
            self.assert_valid_new_owner::<Verifier>(current_owner, new_owner, signature);

            self.emit(OwnerRemoved { removed_owner_guid });
            self._set_public_key(new_public_key);
        }
    }

    /// Adds camelCase support for `ISRC6`.
    #[embeddable_as(SRC6CamelOnlyImpl)]
    impl SRC6CamelOnly<
        TContractState,
        impl Verifier: Falcon512SignatureVerifier,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::ISRC6CamelOnly<ComponentState<TContractState>> {
        fn isValidSignature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>,
        ) -> felt252 {
            SRC6::is_valid_signature(self, hash, signature)
        }
    }

    /// Adds camelCase support for `IFeltArrayPublicKey`.
    #[embeddable_as(PublicKeyCamelImpl)]
    impl PublicKeyCamel<
        TContractState,
        impl Verifier: Falcon512SignatureVerifier,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IFeltArrayPublicKeyCamel<ComponentState<TContractState>> {
        fn getPublicKey(self: @ComponentState<TContractState>) -> Array<felt252> {
            self.read_public_key()
        }

        fn setPublicKey(
            ref self: ComponentState<TContractState>,
            newPublicKey: Array<felt252>,
            signature: Span<felt252>,
        ) {
            PublicKey::set_public_key(ref self, newPublicKey, signature);
        }
    }

    #[embeddable_as(Falcon512AccountMixinImpl)]
    impl Falcon512AccountMixin<
        TContractState,
        impl Verifier: Falcon512SignatureVerifier,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::FeltArrayAccountABI<ComponentState<TContractState>> {
        fn __execute__(self: @ComponentState<TContractState>, calls: Array<Call>) {
            SRC6::__execute__(self, calls)
        }

        fn __validate__(self: @ComponentState<TContractState>, calls: Array<Call>) -> felt252 {
            SRC6::__validate__(self, calls)
        }

        fn is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>,
        ) -> felt252 {
            SRC6::is_valid_signature(self, hash, signature)
        }

        fn isValidSignature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>,
        ) -> felt252 {
            SRC6CamelOnly::isValidSignature(self, hash, signature)
        }

        fn __validate_declare__(
            self: @ComponentState<TContractState>, class_hash: felt252,
        ) -> felt252 {
            Declarer::__validate_declare__(self, class_hash)
        }

        fn __validate_deploy__(
            self: @ComponentState<TContractState>,
            class_hash: felt252,
            contract_address_salt: felt252,
            public_key: Array<felt252>,
        ) -> felt252 {
            Deployable::__validate_deploy__(self, class_hash, contract_address_salt, public_key)
        }

        fn get_public_key(self: @ComponentState<TContractState>) -> Array<felt252> {
            PublicKey::get_public_key(self)
        }

        fn set_public_key(
            ref self: ComponentState<TContractState>,
            new_public_key: Array<felt252>,
            signature: Span<felt252>,
        ) {
            PublicKey::set_public_key(ref self, new_public_key, signature);
        }

        fn getPublicKey(self: @ComponentState<TContractState>) -> Array<felt252> {
            PublicKeyCamel::getPublicKey(self)
        }

        fn setPublicKey(
            ref self: ComponentState<TContractState>,
            newPublicKey: Array<felt252>,
            signature: Span<felt252>,
        ) {
            PublicKeyCamel::setPublicKey(ref self, newPublicKey, signature);
        }

        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252,
        ) -> bool {
            let src5 = get_dep_component!(self, SRC5);
            src5.supports_interface(interface_id)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Validates and stores the packed public key and registers SRC6 support.
        ///
        /// Emits an `OwnerAdded` event.
        fn initializer<impl Verifier: Falcon512SignatureVerifier>(
            ref self: ComponentState<TContractState>, public_key: Array<felt252>,
        ) {
            assert(Verifier::is_valid_public_key(public_key.span()), Errors::INVALID_PUBLIC_KEY);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::ISRC6_ID);

            self._set_public_key(public_key);
        }

        /// Validates that the caller is the account itself. Otherwise it reverts.
        fn assert_only_self(self: @ComponentState<TContractState>) {
            let caller = starknet::get_caller_address();
            let self = starknet::get_contract_address();
            assert(self == caller, Errors::UNAUTHORIZED);
        }

        /// Validates that the new owner accepted ownership of the account.
        ///
        /// WARNING: This function assumes that `current_owner` is the account's current owner.
        fn assert_valid_new_owner<impl Verifier: Falcon512SignatureVerifier>(
            self: @ComponentState<TContractState>,
            current_owner: Span<felt252>,
            new_owner: Span<felt252>,
            signature: Span<felt252>,
        ) {
            let message_hash = PoseidonTrait::new()
                .update_with('StarkNet Message')
                .update_with('accept_ownership')
                .update_with(starknet::get_contract_address())
                .update_with(poseidon_hash_span(current_owner))
                .finalize();

            assert(Verifier::verify(message_hash, new_owner, signature), Errors::INVALID_SIGNATURE);
        }

        /// Validates the transaction hash against the transaction signature.
        fn validate_transaction<impl Verifier: Falcon512SignatureVerifier>(
            self: @ComponentState<TContractState>,
        ) -> felt252 {
            let tx_info = starknet::get_tx_info().unbox();
            assert(
                Verifier::verify(
                    tx_info.transaction_hash, self.read_public_key().span(), tx_info.signature,
                ),
                Errors::INVALID_SIGNATURE,
            );
            starknet::VALIDATED
        }

        /// Sets the public key without validating the caller or key encoding.
        /// The usage of this method outside the initializer and `set_public_key` is discouraged.
        ///
        /// Emits an `OwnerAdded` event.
        fn _set_public_key(
            ref self: ComponentState<TContractState>, new_public_key: Array<felt252>,
        ) {
            let new_owner_guid = poseidon_hash_span(new_public_key.span());
            let stored_len = self.public_key.len();

            if stored_len == 0 {
                for felt in new_public_key {
                    self.public_key.push(felt);
                }
            } else {
                assert(stored_len == new_public_key.len().into(), Errors::INVALID_PUBLIC_KEY);
                let mut index = 0;
                for felt in new_public_key {
                    self.public_key.at(index).write(felt);
                    index += 1;
                }
            }

            self.emit(OwnerAdded { new_owner_guid });
        }

        /// Reads the stored public key into its 29-felt packed representation.
        fn read_public_key(self: @ComponentState<TContractState>) -> Array<felt252> {
            let mut public_key = array![];
            let len = self.public_key.len();
            let mut index = 0;
            while index != len {
                public_key.append(self.public_key.at(index).read());
                index += 1;
            }
            public_key
        }
    }
}
