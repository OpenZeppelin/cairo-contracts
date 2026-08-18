// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1
// (account/src/multisig_account/multisig_account.cairo)

/// # MultisigAccount Component
///
/// The MultisigAccount component enables contracts to behave as accounts authorized by a quorum
/// of Stark-curve signer keys. Each account signature contains a format version, a signer count,
/// and a strictly increasing numeric sequence of `[signer_public_key, r, s]` records. Every
/// `(r, s)` pair signs the same message hash.
///
/// Signer and quorum updates are authorized through account self-calls, allowing the current
/// signer quorum to manage the account configuration.
#[starknet::component]
pub mod MultisigAccountComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::accounts as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use openzeppelin_utils::execution::execute_single_call;
    use starknet::account::Call;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::multisig_account::storage_utils::{SignersInfo, SignersInfoStorePacking};
    use crate::utils::{is_tx_version_valid, is_valid_stark_signature};

    /// Identifies the supported multisig signature encoding.
    pub const SIGNATURE_VERSION: felt252 = 1;

    const SIGNATURE_HEADER_LENGTH: u32 = 2;
    const SIGNATURE_RECORD_LENGTH: u32 = 3;

    #[storage]
    pub struct Storage {
        pub MultisigAccount_signers_info: SignersInfo,
        pub MultisigAccount_is_signer: Map<felt252, bool>,
        pub MultisigAccount_signers_by_index: Map<u32, felt252>,
        pub MultisigAccount_signers_indices: Map<felt252, u32>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        SignerAdded: SignerAdded,
        SignerRemoved: SignerRemoved,
        QuorumUpdated: QuorumUpdated,
    }

    /// Emitted when `signer` is added to the account.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct SignerAdded {
        #[key]
        pub signer: felt252,
    }

    /// Emitted when `signer` is removed from the account.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct SignerRemoved {
        #[key]
        pub signer: felt252,
    }

    /// Emitted when the account quorum changes.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct QuorumUpdated {
        pub old_quorum: u32,
        pub new_quorum: u32,
    }

    pub mod Errors {
        pub const INVALID_CALLER: felt252 = 'MultisigAccount: invalid caller';
        pub const INVALID_SIGNATURE: felt252 = 'MultisigAccount: invalid sig';
        pub const INVALID_TX_VERSION: felt252 = 'MultisigAccount: bad tx version';
        pub const UNAUTHORIZED: felt252 = 'MultisigAccount: unauthorized';
        pub const NOT_A_SIGNER: felt252 = 'MultisigAccount: not signer';
        pub const ALREADY_A_SIGNER: felt252 = 'MultisigAccount: already signer';
        pub const ZERO_SIGNER: felt252 = 'MultisigAccount: zero signer';
        pub const ZERO_QUORUM: felt252 = 'MultisigAccount: zero quorum';
        pub const QUORUM_TOO_HIGH: felt252 = 'MultisigAccount: high quorum';
    }

    //
    // External
    //

    #[embeddable_as(SRC6Impl)]
    impl SRC6<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::ISRC6<ComponentState<TContractState>> {
        /// Executes a list of calls from the account.
        ///
        /// Requirements:
        ///
        /// - The caller must be the Starknet protocol.
        /// - The transaction version must be supported.
        fn __execute__(self: @ComponentState<TContractState>, calls: Array<Call>) {
            let sender = starknet::get_caller_address();
            assert(sender.is_zero(), Errors::INVALID_CALLER);
            assert(is_tx_version_valid(), Errors::INVALID_TX_VERSION);

            for call in calls.span() {
                execute_single_call(call);
            }
        }

        /// Verifies the signer quorum for the current `invoke` transaction.
        fn __validate__(self: @ComponentState<TContractState>, calls: Array<Call>) -> felt252 {
            self.validate_transaction()
        }

        /// Verifies a signer quorum for `hash`.
        fn is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>,
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
        +Drop<TContractState>,
    > of interface::IDeclarer<ComponentState<TContractState>> {
        /// Verifies the signer quorum for the current `declare` transaction.
        fn __validate_declare__(
            self: @ComponentState<TContractState>, class_hash: felt252,
        ) -> felt252 {
            self.validate_transaction()
        }
    }

    #[embeddable_as(DeployableImpl)]
    impl Deployable<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IMultisigDeployable<ComponentState<TContractState>> {
        /// Verifies the signer quorum for the current `deploy_account` transaction.
        fn __validate_deploy__(
            self: @ComponentState<TContractState>,
            class_hash: felt252,
            contract_address_salt: felt252,
            quorum: u32,
            signers: Span<felt252>,
        ) -> felt252 {
            self.validate_transaction()
        }
    }

    #[embeddable_as(MultisigImpl)]
    impl Multisig<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IMultisigAccount<ComponentState<TContractState>> {
        /// Returns the minimum number of signer records required to authorize an operation.
        fn get_quorum(self: @ComponentState<TContractState>) -> u32 {
            self.MultisigAccount_signers_info.read().quorum
        }

        /// Returns whether `signer` is a registered signer public key.
        fn is_signer(self: @ComponentState<TContractState>, signer: felt252) -> bool {
            self.MultisigAccount_is_signer.read(signer)
        }

        /// Returns all registered signer public keys in registry order.
        ///
        /// Registry order is not sorted and can change when signers are removed.
        fn get_signers(self: @ComponentState<TContractState>) -> Span<felt252> {
            let mut signers = array![];
            let signers_count = self.MultisigAccount_signers_info.read().signers_count;
            for index in 0..signers_count {
                signers.append(self.MultisigAccount_signers_by_index.read(index));
            }
            signers.span()
        }

        /// Adds signer public keys and sets the quorum to `new_quorum`.
        /// Already registered public keys are ignored.
        ///
        /// Requirements:
        ///
        /// - The caller must be the account itself.
        /// - Every added signer must be non-zero.
        /// - `new_quorum` must be valid for the resulting signer set.
        ///
        /// Emits a `SignerAdded` event for each newly registered signer and a `QuorumUpdated` event
        /// if the quorum changes.
        fn add_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_add: Span<felt252>,
        ) {
            self.assert_only_self();
            self._add_signers(new_quorum, signers_to_add);
        }

        /// Removes signer public keys and sets the quorum to `new_quorum`.
        /// Unregistered public keys are ignored. Removing signers can change registry order.
        ///
        /// Requirements:
        ///
        /// - The caller must be the account itself.
        /// - `new_quorum` must be valid for the resulting signer set.
        ///
        /// Emits a `SignerRemoved` event for each removed signer and a `QuorumUpdated` event if the
        /// quorum changes.
        fn remove_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_remove: Span<felt252>,
        ) {
            self.assert_only_self();
            self._remove_signers(new_quorum, signers_to_remove);
        }

        /// Replaces one signer public key with another.
        ///
        /// Requirements:
        ///
        /// - The caller must be the account itself.
        /// - `signer_to_remove` must be registered.
        /// - `signer_to_add` must be non-zero and unregistered.
        ///
        /// Emits a `SignerRemoved` event followed by a `SignerAdded` event.
        fn replace_signer(
            ref self: ComponentState<TContractState>,
            signer_to_remove: felt252,
            signer_to_add: felt252,
        ) {
            self.assert_only_self();
            self._replace_signer(signer_to_remove, signer_to_add);
        }

        /// Sets the number of signer records required to authorize an operation.
        ///
        /// Requirements:
        ///
        /// - The caller must be the account itself.
        /// - `new_quorum` must be non-zero and no greater than the signer count.
        ///
        /// Emits a `QuorumUpdated` event if the quorum changes.
        fn change_quorum(ref self: ComponentState<TContractState>, new_quorum: u32) {
            self.assert_only_self();
            self._change_quorum(new_quorum);
        }
    }

    /// Adds camelCase support for `ISRC6`.
    #[embeddable_as(SRC6CamelOnlyImpl)]
    impl SRC6CamelOnly<
        TContractState,
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

    #[embeddable_as(MultisigAccountMixinImpl)]
    impl MultisigAccountMixin<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::MultisigAccountABI<ComponentState<TContractState>> {
        // ISRC6
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

        // ISRC6CamelOnly
        fn isValidSignature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Array<felt252>,
        ) -> felt252 {
            SRC6CamelOnly::isValidSignature(self, hash, signature)
        }

        // IDeclarer
        fn __validate_declare__(
            self: @ComponentState<TContractState>, class_hash: felt252,
        ) -> felt252 {
            Declarer::__validate_declare__(self, class_hash)
        }

        // IMultisigDeployable
        fn __validate_deploy__(
            self: @ComponentState<TContractState>,
            class_hash: felt252,
            contract_address_salt: felt252,
            quorum: u32,
            signers: Span<felt252>,
        ) -> felt252 {
            Deployable::__validate_deploy__(
                self, class_hash, contract_address_salt, quorum, signers,
            )
        }

        // IMultisigAccount
        fn get_quorum(self: @ComponentState<TContractState>) -> u32 {
            Multisig::get_quorum(self)
        }

        fn is_signer(self: @ComponentState<TContractState>, signer: felt252) -> bool {
            Multisig::is_signer(self, signer)
        }

        fn get_signers(self: @ComponentState<TContractState>) -> Span<felt252> {
            Multisig::get_signers(self)
        }

        fn add_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_add: Span<felt252>,
        ) {
            Multisig::add_signers(ref self, new_quorum, signers_to_add)
        }

        fn remove_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_remove: Span<felt252>,
        ) {
            Multisig::remove_signers(ref self, new_quorum, signers_to_remove)
        }

        fn replace_signer(
            ref self: ComponentState<TContractState>,
            signer_to_remove: felt252,
            signer_to_add: felt252,
        ) {
            Multisig::replace_signer(ref self, signer_to_remove, signer_to_add)
        }

        fn change_quorum(ref self: ComponentState<TContractState>, new_quorum: u32) {
            Multisig::change_quorum(ref self, new_quorum)
        }

        // ISRC5
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252,
        ) -> bool {
            let src5 = get_dep_component!(self, SRC5);
            src5.supports_interface(interface_id)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the signer set and quorum and registers the `ISRC6` interface ID.
        ///
        /// Requirements:
        ///
        /// - Every signer must be non-zero.
        /// - `quorum` must be non-zero and no greater than the number of unique signers.
        ///
        /// Emits a `SignerAdded` event for each unique signer and a `QuorumUpdated` event when
        /// setting the initial quorum.
        fn initializer(
            ref self: ComponentState<TContractState>, quorum: u32, signers: Span<felt252>,
        ) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::ISRC6_ID);
            self._add_signers(quorum, signers);
        }

        /// Asserts that the caller is the account itself.
        fn assert_only_self(self: @ComponentState<TContractState>) {
            let caller = starknet::get_caller_address();
            let account_address = starknet::get_contract_address();
            assert(caller == account_address, Errors::UNAUTHORIZED);
        }

        /// Verifies the signer quorum for the transaction hash and signature in the execution
        /// context.
        fn validate_transaction(self: @ComponentState<TContractState>) -> felt252 {
            let tx_info = starknet::get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(self._is_valid_signature(tx_hash, signature), Errors::INVALID_SIGNATURE);
            starknet::VALIDATED
        }

        /// Returns whether `signature` contains a valid signer quorum for `hash`.
        ///
        /// The signature is encoded as
        /// `[version, signer_count, signer_public_key, r, s, ...]`. Signer records must be ordered
        /// by strictly increasing numeric public key. Every supplied record must belong to a
        /// registered signer and contain a valid Stark-curve signature for `hash`.
        ///
        /// A zero stored quorum is invalid, so uninitialized component storage fails closed.
        fn _is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Span<felt252>,
        ) -> bool {
            let signature_len = signature.len();
            if signature_len < SIGNATURE_HEADER_LENGTH {
                return false;
            }

            let records_len = signature_len - SIGNATURE_HEADER_LENGTH;
            if records_len % SIGNATURE_RECORD_LENGTH != 0 {
                return false;
            }

            let provided_signer_count = records_len / SIGNATURE_RECORD_LENGTH;
            if *signature.at(0) != SIGNATURE_VERSION
                || *signature.at(1) != provided_signer_count.into() {
                return false;
            }

            let SignersInfo { quorum, signers_count } = self.MultisigAccount_signers_info.read();
            if quorum.is_zero() {
                return false;
            }
            if provided_signer_count < quorum || provided_signer_count > signers_count {
                return false;
            }

            let mut previous_signer_value: u256 = 0;
            let mut record_offset = SIGNATURE_HEADER_LENGTH;
            while record_offset < signature_len {
                let signer = *signature.at(record_offset);
                let signer_value: u256 = signer.into();
                // Strict ordering canonicalizes the encoding and rejects duplicate signer keys.
                if signer_value <= previous_signer_value {
                    return false;
                }
                if !Multisig::is_signer(self, signer) {
                    return false;
                }

                let signer_signature = array![
                    *signature.at(record_offset + 1), *signature.at(record_offset + 2),
                ];
                if !is_valid_stark_signature(hash, signer, signer_signature.span()) {
                    return false;
                }

                previous_signer_value = signer_value;
                record_offset += SIGNATURE_RECORD_LENGTH;
            }

            true
        }

        /// Adds unregistered signer public keys and sets the quorum to `new_quorum`.
        /// Already registered public keys are ignored.
        ///
        /// The caller is responsible for enforcing authorization.
        fn _add_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_add: Span<felt252>,
        ) {
            if !signers_to_add.is_empty() {
                let SignersInfo {
                    quorum: current_quorum, mut signers_count,
                } = self.MultisigAccount_signers_info.read();
                for signer in signers_to_add {
                    let signer_to_add = *signer;
                    assert(signer_to_add.is_non_zero(), Errors::ZERO_SIGNER);
                    if Multisig::is_signer(@self, signer_to_add) {
                        continue;
                    }

                    let signer_index = signers_count;
                    self.MultisigAccount_is_signer.write(signer_to_add, true);
                    self.MultisigAccount_signers_by_index.write(signer_index, signer_to_add);
                    self.MultisigAccount_signers_indices.write(signer_to_add, signer_index);
                    self.emit(SignerAdded { signer: signer_to_add });
                    signers_count += 1;
                }
                self
                    .MultisigAccount_signers_info
                    .write(SignersInfo { quorum: current_quorum, signers_count });
            }
            self._change_quorum(new_quorum);
        }

        /// Removes registered signer public keys and sets the quorum to `new_quorum`.
        /// Unregistered public keys are ignored.
        ///
        /// The caller is responsible for enforcing authorization.
        fn _remove_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_remove: Span<felt252>,
        ) {
            if !signers_to_remove.is_empty() {
                let SignersInfo {
                    quorum: current_quorum, mut signers_count,
                } = self.MultisigAccount_signers_info.read();
                for signer in signers_to_remove {
                    let signer_to_remove = *signer;
                    if !Multisig::is_signer(@self, signer_to_remove) {
                        continue;
                    }

                    let last_index = signers_count - 1;
                    let removed_index = self.MultisigAccount_signers_indices.read(signer_to_remove);
                    if removed_index != last_index {
                        // Move the last signer into the removed signer's registry slot.
                        let last_signer = self.MultisigAccount_signers_by_index.read(last_index);
                        self.MultisigAccount_signers_indices.write(last_signer, removed_index);
                        self.MultisigAccount_signers_by_index.write(removed_index, last_signer);
                    }

                    // Clear the old last slot after the move.
                    self.MultisigAccount_is_signer.write(signer_to_remove, false);
                    self.MultisigAccount_signers_by_index.write(last_index, Zero::zero());
                    self.MultisigAccount_signers_indices.write(signer_to_remove, 0);
                    self.emit(SignerRemoved { signer: signer_to_remove });
                    signers_count -= 1;
                }
                self
                    .MultisigAccount_signers_info
                    .write(SignersInfo { quorum: current_quorum, signers_count });
            }
            self._change_quorum(new_quorum);
        }

        /// Replaces one signer public key with another.
        ///
        /// The caller is responsible for enforcing authorization.
        fn _replace_signer(
            ref self: ComponentState<TContractState>,
            signer_to_remove: felt252,
            signer_to_add: felt252,
        ) {
            assert(signer_to_add.is_non_zero(), Errors::ZERO_SIGNER);
            assert(!Multisig::is_signer(@self, signer_to_add), Errors::ALREADY_A_SIGNER);
            assert(Multisig::is_signer(@self, signer_to_remove), Errors::NOT_A_SIGNER);

            let signer_index = self.MultisigAccount_signers_indices.read(signer_to_remove);
            self.MultisigAccount_is_signer.write(signer_to_remove, false);
            self.MultisigAccount_is_signer.write(signer_to_add, true);
            self.MultisigAccount_signers_by_index.write(signer_index, signer_to_add);
            self.MultisigAccount_signers_indices.write(signer_to_add, signer_index);
            self.MultisigAccount_signers_indices.write(signer_to_remove, 0);
            self.emit(SignerRemoved { signer: signer_to_remove });
            self.emit(SignerAdded { signer: signer_to_add });
        }

        /// Sets the number of signer records required to authorize an operation.
        ///
        /// The caller is responsible for enforcing authorization.
        fn _change_quorum(ref self: ComponentState<TContractState>, new_quorum: u32) {
            let SignersInfo {
                quorum: old_quorum, signers_count,
            } = self.MultisigAccount_signers_info.read();
            assert(new_quorum.is_non_zero(), Errors::ZERO_QUORUM);
            assert(new_quorum <= signers_count, Errors::QUORUM_TOO_HIGH);
            if new_quorum != old_quorum {
                self
                    .MultisigAccount_signers_info
                    .write(SignersInfo { quorum: new_quorum, signers_count });
                self.emit(QuorumUpdated { old_quorum, new_quorum });
            }
        }
    }
}
