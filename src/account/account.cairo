// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.9.0 (account/account.cairo)

/// # Account Component
///
/// The Account component enables contracts to behave as accounts.
#[starknet::component]
mod AccountComponent {
    use openzeppelin::account::interface;
    use openzeppelin::account::utils::add_owner::AddOwner;
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
        Account_public_key: felt252
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnerAdded: OwnerAdded,
        OwnerRemoved: OwnerRemoved
    }

    #[derive(Drop, starknet::Event)]
    struct OwnerAdded {
        #[key]
        new_owner_guid: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct OwnerRemoved {
        #[key]
        removed_owner_guid: felt252
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

    #[embeddable_as(PublicKeyImpl)]
    impl PublicKey<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IPublicKey<ComponentState<TContractState>> {
        /// Returns the current public key of the account.
        fn get_public_key(self: @ComponentState<TContractState>) -> felt252 {
            self.Account_public_key.read()
        }

        /// Sets the public key of the account to `new_public_key`.
        ///
        /// Requirements:
        ///
        /// - The caller must be the contract itself.
        ///
        /// Emits an `OwnerRemoved` event.
        fn set_public_key(ref self: ComponentState<TContractState>, new_public_key: felt252, signature: Span<felt252>) {
            self.assert_only_self();

            let hash = AddOwner::build_hash(new_public_key);
            assert(self._is_valid_signature(hash, signature), Errors::INVALID_SIGNATURE);

            self.emit(OwnerRemoved { removed_owner_guid: self.Account_public_key.read() });
            self._set_public_key(new_public_key);
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
    #[embeddable_as(PublicKeyCamelImpl)]
    impl PublicKeyCamel<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IPublicKeyCamel<ComponentState<TContractState>> {
        fn getPublicKey(self: @ComponentState<TContractState>) -> felt252 {
            self.Account_public_key.read()
        }

        fn setPublicKey(ref self: ComponentState<TContractState>, newPublicKey: felt252, signature: Span<felt252>) {
            self.set_public_key(newPublicKey, signature);
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
            self._set_public_key(public_key);
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
        fn _set_public_key(ref self: ComponentState<TContractState>, new_public_key: felt252) {
            self.Account_public_key.write(new_public_key);
            self.emit(OwnerAdded { new_owner_guid: new_public_key });
        }

        /// Returns whether the given signature is valid for the given hash
        /// using the account's current public key.
        fn _is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Span<felt252>
        ) -> bool {
            let public_key = self.Account_public_key.read();
            is_valid_stark_signature(hash, public_key, signature)
        }
    }
}
