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

/// Account component for immutable, array-encoded Falcon-512 public keys.
#[starknet::component]
pub(crate) mod Falcon512AccountComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::accounts as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_utils::execution::execute_single_call;
    use starknet::account::Call;
    use starknet::storage::{MutableVecTrait, StoragePointerReadAccess, Vec, VecTrait};
    use crate::utils::is_tx_version_valid;
    use super::Falcon512SignatureVerifier;

    #[storage]
    pub struct Storage {
        pub public_key: Vec<felt252>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    pub mod Errors {
        pub const INVALID_CALLER: felt252 = 'Account: invalid caller';
        pub const INVALID_PUBLIC_KEY: felt252 = 'Account: invalid public key';
        pub const INVALID_SIGNATURE: felt252 = 'Account: invalid signature';
        pub const INVALID_TX_VERSION: felt252 = 'Account: invalid tx version';
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
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IFeltArrayPublicKey<ComponentState<TContractState>> {
        /// Returns the immutable packed Falcon-512 public key.
        fn get_public_key(self: @ComponentState<TContractState>) -> Array<felt252> {
            self.read_public_key()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Validates and stores the immutable packed public key and registers SRC6 support.
        fn initializer<impl Verifier: Falcon512SignatureVerifier>(
            ref self: ComponentState<TContractState>, public_key: Array<felt252>,
        ) {
            assert(Verifier::is_valid_public_key(public_key.span()), Errors::INVALID_PUBLIC_KEY);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::ISRC6_ID);

            for felt in public_key {
                self.public_key.push(felt);
            }
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
