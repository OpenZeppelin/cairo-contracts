// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.9.0 (account/account.cairo)

/// # Multisig Account Component
///
/// The Multisig Account component enables contracts to behave as accounts with multiple signers.
#[starknet::component]
mod MultisigAccountComponent {
    use openzeppelin::account::interface::IPublicKeys;
    use openzeppelin::account::interface;
    use openzeppelin::account::utils::{MIN_TRANSACTION_VERSION, QUERY_VERSION, QUERY_OFFSET};
    use openzeppelin::account::utils::{execute_calls, is_valid_stark_signature};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::account::Call;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_tx_info;

    #[storage]
    struct Storage {
        account_public_keys: LegacyMap<usize, felt252>,
        number_of_signers: usize,
        threshold: usize,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewSignerAdded: NewSignerAdded,
        SignerRemoved: SignerRemoved,
        ThresholdUpdated: ThresholdUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct NewSignerAdded {
        #[key]
        new_signer_public_key: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct SignerRemoved {
        #[key]
        removed_signer_public_key: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct ThresholdUpdated {
        #[key]
        old_threshold: usize,
        #[key]
        new_threshold: usize
    }

    mod Errors {
        const INVALID_CALLER: felt252 = 'Account: invalid caller';
        const INVALID_SIGNATURE: felt252 = 'Account: invalid signature';
        const INVALID_TX_VERSION: felt252 = 'Account: invalid tx version';
        const UNAUTHORIZED: felt252 = 'Account: unauthorized';
    }

    #[embeddable_as(SRC6Impl)]
    impl SRC6<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::ISRC6<ComponentState<TContractState>> {
        /// Executes a list of calls from the account.
        ///
        /// Requirements:
        ///
        /// - The transaction version must be greater than or equal to `MIN_TRANSACTION_VERSION`.
        /// - If the transaction is a simulation (version than `QUERY_OFFSET`), it must be
        /// greater than or equal to `QUERY_OFFSET` + `MIN_TRANSACTION_VERSION`.
        fn __execute__(
            self: @ComponentState<TContractState>, mut calls: Array<Call>
        ) -> Array<Span<felt252>> {
            // Avoid calls from other contracts
            // https://github.com/OpenZeppelin/cairo-contracts/issues/344
            let sender = get_caller_address();
            assert(sender.is_zero(), Errors::INVALID_CALLER);

            // Check tx version
            let tx_info = get_tx_info().unbox();
            let tx_version: u256 = tx_info.version.into();
            // Check if tx is a query
            if (tx_version >= QUERY_OFFSET) {
                assert(
                    QUERY_OFFSET + MIN_TRANSACTION_VERSION <= tx_version, Errors::INVALID_TX_VERSION
                );
            } else {
                assert(MIN_TRANSACTION_VERSION <= tx_version, Errors::INVALID_TX_VERSION);
            }

            execute_calls(calls)
        }

        /// Verifies the validity of the signature for the current transaction.
        /// This function is used by the protocol to verify `invoke` transactions.
        fn __validate__(self: @ComponentState<TContractState>, mut calls: Array<Call>) -> felt252 {
            self.validate_transaction()
        }

        /// Verifies that the given signature is valid for the given hash.
        fn is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            if self._is_valid_signature(hash, signature.span()) {
                starknet::VALIDATED
            } else {
                0
            }
        }
    }

    #[embeddable_as(DeclarerImpl)]
    impl Declarer<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IDeclarer<ComponentState<TContractState>> {
        /// Verifies the validity of the signature for the current transaction.
        /// This function is used by the protocol to verify `declare` transactions.
        fn __validate_declare__(
            self: @ComponentState<TContractState>, class_hash: felt252
        ) -> felt252 {
            self.validate_transaction()
        }
    }

    #[embeddable_as(DeployableImpl)]
    impl Deployable<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IDeployable<ComponentState<TContractState>> {
        /// Verifies the validity of the signature for the current transaction.
        /// This function is used by the protocol to verify `deploy_account` transactions.
        fn __validate_deploy__(
            self: @ComponentState<TContractState>,
            class_hash: felt252,
            contract_address_salt: felt252,
            public_key: felt252
        ) -> felt252 {
            self.validate_transaction()
        }
    }

    #[embeddable_as(PublicKeysImpl)]
    impl PublicKeys<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IPublicKeys<ComponentState<TContractState>> {
        /// Returns the current public keys associated to the account.
        fn get_public_keys(self: @ComponentState<TContractState>) -> Span<felt252> {
            let mut result: Array<felt252> = array![];
            let mut i: usize = 0;
            while i != self.number_of_signers.read() {
                let public_key: felt252 = self.account_public_keys.read(i);
                result.append(public_key);
                i += 1;
            };

            result.span()
        }

        /// Adds a public key of the multisig account.
        fn add_public_key(ref self: ComponentState<TContractState>, new_public_key: felt252) {
            self.assert_only_self();
            self.emit(NewSignerAdded { new_signer_public_key: new_public_key });
            self._add_public_key(new_public_key);
        }

        /// Removes a public key of the multisig account.
        fn remove_public_key(ref self: ComponentState<TContractState>, public_key: felt252) {
            self.assert_only_self();
            // Check missing to make sure the public_key passed as argument is indeed a public key of this account
            self.emit(SignerRemoved { removed_signer_public_key: public_key });

            let mut i = 0;
            while i != self.number_of_signers.read() {
                if self.account_public_keys.read(i) == public_key {
                    let mut j = i;
                    while j != self.number_of_signers.read() {
                        self.account_public_keys.write(j, self.account_public_keys.read(j + 1));
                        j += 1;
                    }
                }

                i += 1;
            }
        }
    }

    /// Adds camelCase support for `ISRC6`.
    #[embeddable_as(SRC6CamelOnlyImpl)]
    impl SRC6CamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::ISRC6CamelOnly<ComponentState<TContractState>> {
        fn isValidSignature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            self.is_valid_signature(hash, signature)
        }
    }

    /// Adds camelCase support for `PublicKeyTrait`.
    #[embeddable_as(PublicKeysCamelImpl)]
    impl PublicKeysCamel<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IPublicKeysCamel<ComponentState<TContractState>> {
        fn getPublicKeys(self: @ComponentState<TContractState>) -> Span<felt252> {
            self.get_public_keys()
        }

        fn addPublicKey(ref self: ComponentState<TContractState>, newPublicKey: felt252) {
            self.add_public_key(newPublicKey);
        }

        fn removePublicKey(ref self: ComponentState<TContractState>, newPublicKey: felt252) {
            self.remove_public_key(newPublicKey);
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the account by setting the initial public key
        /// and registering the ISRC6 interface Id.
        fn initializer(ref self: ComponentState<TContractState>, public_key: felt252) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::ISRC6_ID);
            self._add_public_key(public_key);
        }

        /// Validates that the caller is the account itself. Otherwise it reverts.
        fn assert_only_self(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            let self = get_contract_address();
            assert(self == caller, Errors::UNAUTHORIZED);
        }

        /// Validates the signature for the current transaction.
        /// Returns the short string `VALID` if valid, otherwise it reverts.
        fn validate_transaction(self: @ComponentState<TContractState>) -> felt252 {
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(self._is_valid_signature(tx_hash, signature), Errors::INVALID_SIGNATURE);
            starknet::VALIDATED
        }

        /// Sets the public key without validating the caller.
        /// The usage of this method outside the `set_public_key` function is discouraged.
        ///
        /// Emits an `OwnerAdded` event.
        fn _add_public_key(ref self: ComponentState<TContractState>, new_public_key: felt252) {
            let position = self.number_of_signers.read();
            self.account_public_keys.write(position, new_public_key);
            self.emit(NewSignerAdded { new_signer_public_key: new_public_key });
        }

        /// Returns whether the given signature is valid for the given hash
        /// using the account's current public key.
        fn _is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Span<felt252>
        ) -> bool {
            let threshold = self.threshold.read();
            // assert there is 1 signature per required signer
            assert(signature.len() == threshold * 2, 'invalid signature length');

            let mut final_result: bool = false;
            let mut signer_signatures = signature;
            loop {
                match signer_signatures.pop_front() {
                    Option::Some(r) => {
                        match signer_signatures.pop_front() {
                            Option::Some(s) => {
                                let sig = array![*r, *s].span();
                                let mut result: bool = false;
                                let mut i: usize = 0;
                                while i != self.number_of_signers.read() {
                                    result =
                                        is_valid_stark_signature(
                                            hash, self.account_public_keys.read(i), sig
                                        );

                                    if result {
                                        final_result = true;
                                        break;
                                    }

                                    i += 1;
                                };

                                if !result {
                                    final_result = false;
                                    break;
                                }
                            },
                            Option::None => { break; }
                        }
                    },
                    Option::None => { break; }
                };
            };

            final_result
        }
    }
}
