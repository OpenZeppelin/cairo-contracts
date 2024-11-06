// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (governance/multisig/multisig.cairo)

/// # Multisig Component
#[starknet::component]
pub mod MultisigComponent {
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::num::traits::Zero;
    use core::panic_with_felt252;
    use core::pedersen::PedersenTrait;
    use crate::multisig::interface::{IMultisig, TransactionID, TransactionState};
    use crate::timelock::utils::call_impls::{HashCallImpl, HashCallsImpl, CallPartialEq};
    use starknet::account::Call;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResultTrait};

    #[storage]
    pub struct Storage {
        pub Multisig_quorum: u32,
        pub Multisig_signers_count: u32,
        pub Multisig_is_signer: Map<ContractAddress, bool>,
        pub Multisig_signers_by_index: Map<u32, ContractAddress>,
        pub Multisig_signers_indices: Map<ContractAddress, u32>,
        pub Multisig_tx_confirmed_by: Map<(TransactionID, ContractAddress), bool>,
        pub Multisig_tx_confirmations: Map<TransactionID, u32>,
        pub Multisig_tx_submitted_block: Map<TransactionID, u64>,
        pub Multisig_tx_executed: Map<TransactionID, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SignerAdded: SignerAdded,
        SignerRemoved: SignerRemoved,
        QuorumUpdated: QuorumUpdated,
        TransactionSubmitted: TransactionSubmitted,
        TransactionConfirmed: TransactionConfirmed,
        TransactionExecuted: TransactionExecuted,
        ConfirmationRevoked: ConfirmationRevoked,
        CallSalt: CallSalt
    }

    #[derive(Drop, starknet::Event)]
    pub struct SignerAdded {
        #[key]
        pub signer: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct SignerRemoved {
        #[key]
        pub signer: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct QuorumUpdated {
        pub old_quorum: u32,
        pub new_quorum: u32
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransactionSubmitted {
        #[key]
        pub id: TransactionID,
        #[key]
        pub signer: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransactionConfirmed {
        #[key]
        pub id: TransactionID,
        #[key]
        pub signer: ContractAddress,
        pub total_confirmations: u32
    }

    #[derive(Drop, starknet::Event)]
    pub struct ConfirmationRevoked {
        #[key]
        pub id: TransactionID,
        #[key]
        pub signer: ContractAddress,
        pub total_confirmations: u32
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransactionExecuted {
        #[key]
        pub id: TransactionID
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CallSalt {
        #[key]
        pub id: felt252,
        pub salt: felt252
    }

    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Multisig: unauthorized';
        pub const NOT_A_SIGNER: felt252 = 'Multisig: not a signer';
        pub const ALREADY_A_SIGNER: felt252 = 'Multisig: already a signer';
        pub const ALREADY_CONFIRMED: felt252 = 'Multisig: already confirmed';
        pub const HAS_NOT_CONFIRMED: felt252 = 'Multisig: has not confirmed';
        pub const TX_ALREADY_EXISTS: felt252 = 'Multisig: tx already exists';
        pub const TX_NOT_FOUND: felt252 = 'Multisig: tx not found';
        pub const TX_NOT_CONFIRMED: felt252 = 'Multisig: tx not confirmed';
        pub const TX_ALREADY_EXECUTED: felt252 = 'Multisig: tx already executed';
        pub const ZERO_ADDRESS: felt252 = 'Multisig: zero address';
        pub const ZERO_QUORUM: felt252 = 'Multisig: quorum cannot be 0';
        pub const QUORUM_TOO_HIGH: felt252 = 'Multisig: quorum > signers';
    }

    #[embeddable_as(MultisigImpl)]
    impl Multisig<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of IMultisig<ComponentState<TContractState>> {
        fn get_quorum(self: @ComponentState<TContractState>) -> u32 {
            self.Multisig_quorum.read()
        }

        fn is_signer(self: @ComponentState<TContractState>, signer: ContractAddress) -> bool {
            self.Multisig_is_signer.read(signer)
        }

        fn get_signers(self: @ComponentState<TContractState>) -> Span<ContractAddress> {
            let signers_count = self.Multisig_signers_count.read();
            let mut result = array![];
            for i in 0..signers_count {
                result.append(self.Multisig_signers_by_index.read(i));
            };
            result.span()
        }

        fn is_confirmed(self: @ComponentState<TContractState>, id: TransactionID) -> bool {
            match self.resolve_tx_state(id) {
                TransactionState::NotFound => false,
                TransactionState::Pending => false,
                TransactionState::Confirmed => true,
                TransactionState::Executed => true
            }
        }

        fn is_confirmed_by(
            self: @ComponentState<TContractState>, id: TransactionID, signer: ContractAddress
        ) -> bool {
            self.Multisig_tx_confirmed_by.read((id, signer))
        }

        fn is_executed(self: @ComponentState<TContractState>, id: TransactionID) -> bool {
            self.Multisig_tx_executed.read(id)
        }

        fn get_transaction_state(
            self: @ComponentState<TContractState>, id: TransactionID
        ) -> TransactionState {
            self.resolve_tx_state(id)
        }

        fn get_transaction_confirmations(
            self: @ComponentState<TContractState>, id: TransactionID
        ) -> u32 {
            self.Multisig_tx_confirmations.read(id)
        }

        fn get_submitted_block(self: @ComponentState<TContractState>, id: TransactionID) -> u64 {
            self.Multisig_tx_submitted_block.read(id)
        }

        fn add_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_add: Span<ContractAddress>
        ) {
            self.assert_only_self();
            self._add_signers(new_quorum, signers_to_add);
        }

        fn remove_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_remove: Span<ContractAddress>
        ) {
            self.assert_only_self();
            self._remove_signers(new_quorum, signers_to_remove);
        }

        fn replace_signer(
            ref self: ComponentState<TContractState>,
            signer_to_remove: ContractAddress,
            signer_to_add: ContractAddress
        ) {
            self.assert_only_self();
            self._replace_signer(signer_to_remove, signer_to_add);
        }

        fn change_quorum(ref self: ComponentState<TContractState>, new_quorum: u32) {
            self.assert_only_self();
            self._change_quorum(new_quorum);
        }

        fn submit_transaction(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            selector: felt252,
            calldata: Span<felt252>,
            salt: felt252
        ) -> TransactionID {
            let call = Call { to, selector, calldata };
            self.submit_transaction_batch(array![call].span(), salt)
        }

        fn submit_transaction_batch(
            ref self: ComponentState<TContractState>, calls: Span<Call>, salt: felt252
        ) -> TransactionID {
            let caller = starknet::get_caller_address();
            self.assert_one_of_signers(caller);
            let id = self.hash_transaction_batch(calls, salt);
            assert(self.get_submitted_block(id).is_zero(), Errors::TX_ALREADY_EXISTS);

            self.Multisig_tx_submitted_block.write(id, starknet::get_block_number());
            if salt.is_non_zero() {
                self.emit(CallSalt { id, salt });
            }
            self.emit(TransactionSubmitted { id, signer: caller });

            id
        }

        fn confirm_transaction(ref self: ComponentState<TContractState>, id: TransactionID) {
            let caller = starknet::get_caller_address();
            self.assert_one_of_signers(caller);
            self.assert_tx_exists(id);
            assert(!self.is_executed(id), Errors::TX_ALREADY_EXECUTED);
            assert(!self.is_confirmed_by(id, caller), Errors::ALREADY_CONFIRMED);

            let total_confirmations = 1 + self.Multisig_tx_confirmations.read(id);
            self.Multisig_tx_confirmations.write(id, total_confirmations);
            self.Multisig_tx_confirmed_by.write((id, caller), true);

            self.emit(TransactionConfirmed { id, signer: caller, total_confirmations });
        }

        fn revoke_confirmation(ref self: ComponentState<TContractState>, id: TransactionID) {
            let caller = starknet::get_caller_address();
            self.assert_tx_exists(id);
            assert(!self.is_executed(id), Errors::TX_ALREADY_EXECUTED);
            assert(self.is_confirmed_by(id, caller), Errors::HAS_NOT_CONFIRMED);

            let total_confirmations = self.Multisig_tx_confirmations.read(id) - 1;
            self.Multisig_tx_confirmations.write(id, total_confirmations);
            self.Multisig_tx_confirmed_by.write((id, caller), false);

            self.emit(ConfirmationRevoked { id, signer: caller, total_confirmations });
        }

        fn execute_transaction(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            selector: felt252,
            calldata: Span<felt252>,
            salt: felt252
        ) {
            let call = Call { to, selector, calldata };
            self.execute_transaction_batch(array![call].span(), salt)
        }

        fn execute_transaction_batch(
            ref self: ComponentState<TContractState>, calls: Span<Call>, salt: felt252
        ) {
            let id = self.hash_transaction_batch(calls, salt);
            match self.resolve_tx_state(id) {
                TransactionState::NotFound => panic_with_felt252(Errors::TX_NOT_FOUND),
                TransactionState::Pending => panic_with_felt252(Errors::TX_NOT_CONFIRMED),
                TransactionState::Executed => panic_with_felt252(Errors::TX_ALREADY_EXECUTED),
                TransactionState::Confirmed => {
                    let caller = starknet::get_caller_address();
                    self.assert_one_of_signers(caller);
                    self.Multisig_tx_executed.write(id, true);
                    for call in calls {
                        let Call { to, selector, calldata } = *call;
                        call_contract_syscall(to, selector, calldata).unwrap_syscall();
                    };
                    self.emit(TransactionExecuted { id });
                }
            };
        }

        fn hash_transaction(
            self: @ComponentState<TContractState>,
            to: ContractAddress,
            selector: felt252,
            calldata: Span<felt252>,
            salt: felt252
        ) -> TransactionID {
            let call = Call { to, selector, calldata };
            self.hash_transaction_batch(array![call].span(), salt)
        }

        fn hash_transaction_batch(
            self: @ComponentState<TContractState>, calls: Span<Call>, salt: felt252
        ) -> TransactionID {
            PedersenTrait::new(0).update_with(calls).update_with(salt).finalize()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>, quorum: u32, signers: Span<ContractAddress>
        ) {
            self._add_signers(quorum, signers);
        }

        fn resolve_tx_state(
            self: @ComponentState<TContractState>, id: TransactionID
        ) -> TransactionState {
            if self.Multisig_tx_submitted_block.read(id).is_zero() {
                TransactionState::NotFound
            } else if self.Multisig_tx_executed.read(id) {
                TransactionState::Executed
            } else {
                let confirmations = self.Multisig_tx_confirmations.read(id);
                let is_confirmed = confirmations >= self.Multisig_quorum.read();
                if is_confirmed {
                    TransactionState::Confirmed
                } else {
                    TransactionState::Pending
                }
            }
        }

        fn assert_one_of_signers(self: @ComponentState<TContractState>, caller: ContractAddress) {
            assert(self.Multisig_is_signer.read(caller), Errors::NOT_A_SIGNER);
        }

        fn assert_tx_exists(self: @ComponentState<TContractState>, id: TransactionID) {
            assert(self.Multisig_tx_submitted_block.read(id).is_non_zero(), Errors::TX_NOT_FOUND);
        }

        fn assert_only_self(self: @ComponentState<TContractState>) {
            let caller = starknet::get_caller_address();
            let self = starknet::get_contract_address();
            assert(caller == self, Errors::UNAUTHORIZED);
        }

        fn _add_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_add: Span<ContractAddress>
        ) {
            if !signers_to_add.is_empty() {
                let mut current_signers_count = self.Multisig_signers_count.read();
                for signer in signers_to_add {
                    let signer_to_add = *signer;
                    assert(signer_to_add.is_non_zero(), Errors::ZERO_ADDRESS);
                    if self.Multisig_is_signer.read(signer_to_add) {
                        continue;
                    }
                    let index = current_signers_count;
                    self.Multisig_is_signer.write(signer_to_add, true);
                    self.Multisig_signers_by_index.write(index, signer_to_add);
                    self.Multisig_signers_indices.write(signer_to_add, index);
                    self.emit(SignerAdded { signer: signer_to_add });

                    current_signers_count += 1;
                };
                self.Multisig_signers_count.write(current_signers_count);
            }
            self._change_quorum(new_quorum);
        }

        fn _remove_signers(
            ref self: ComponentState<TContractState>,
            new_quorum: u32,
            signers_to_remove: Span<ContractAddress>
        ) {
            if !signers_to_remove.is_empty() {
                let mut current_signers_count = self.Multisig_signers_count.read();
                for signer in signers_to_remove {
                    let signer_to_remove = *signer;
                    if !self.Multisig_is_signer.read(signer_to_remove) {
                        continue;
                    }
                    let last_index = current_signers_count - 1;
                    let index = self.Multisig_signers_indices.read(signer_to_remove);
                    if index != last_index {
                        // Swap signer to remove with the last signer
                        let last_signer = self.Multisig_signers_by_index.read(last_index);
                        self.Multisig_signers_indices.write(last_signer, index);
                        self.Multisig_signers_by_index.write(index, last_signer);
                    }
                    // Remove the last signer
                    self.Multisig_is_signer.write(signer_to_remove, false);
                    self.Multisig_signers_by_index.write(last_index, Zero::zero());
                    self.Multisig_signers_indices.write(signer_to_remove, 0);

                    self.emit(SignerRemoved { signer: signer_to_remove });

                    current_signers_count -= 1;
                };
                self.Multisig_signers_count.write(current_signers_count);
            }
            self._change_quorum(new_quorum);
        }

        fn _replace_signer(
            ref self: ComponentState<TContractState>,
            signer_to_remove: ContractAddress,
            signer_to_add: ContractAddress
        ) {
            assert(signer_to_add.is_non_zero(), Errors::ZERO_ADDRESS);
            assert(!self.Multisig_is_signer.read(signer_to_add), Errors::ALREADY_A_SIGNER);
            assert(self.Multisig_is_signer.read(signer_to_remove), Errors::NOT_A_SIGNER);

            self.Multisig_is_signer.write(signer_to_remove, false);
            self.Multisig_is_signer.write(signer_to_add, true);
            let index = self.Multisig_signers_indices.read(signer_to_remove);
            self.Multisig_signers_by_index.write(index, signer_to_add);
            self.Multisig_signers_indices.write(signer_to_add, index);
            self.Multisig_signers_indices.write(signer_to_remove, 0);

            self.emit(SignerRemoved { signer: signer_to_remove });
            self.emit(SignerAdded { signer: signer_to_add });
        }

        fn _change_quorum(ref self: ComponentState<TContractState>, new_quorum: u32) {
            let old_quorum = self.Multisig_quorum.read();
            if new_quorum != old_quorum {
                assert(new_quorum.is_non_zero(), Errors::ZERO_QUORUM);
                let signers_count = self.Multisig_signers_count.read();
                assert(new_quorum <= signers_count, Errors::QUORUM_TOO_HIGH);
                self.Multisig_quorum.write(new_quorum);
                self.emit(QuorumUpdated { old_quorum, new_quorum });
            }
        }
    }
}
