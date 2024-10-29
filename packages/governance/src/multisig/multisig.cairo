// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (governance/multisig/multisig.cairo)

/// # Multisig Component
#[starknet::component]
pub mod MultisigComponent {
    use core::num::traits::Zero;
    use core::panic_with_felt252;
    use crate::multisig::interface::{IMultisig, TransactionID, TransactionStatus};
    use starknet::account::Call;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResultTrait};
    use starknet::{get_caller_address, get_contract_address};

    #[derive(Drop, starknet::Store)]
    struct StorableCallInfo {
        to: ContractAddress,
        selector: felt252,
        calldata_len: u32
    }

    #[storage]
    pub struct Storage {
        pub Multisig_threshold: u32,
        pub Multisig_signers_count: u32,
        pub Multisig_is_signer: Map<ContractAddress, bool>,
        pub Multisig_signers_by_index: Map<u32, ContractAddress>,
        pub Multisig_signers_indices: Map<ContractAddress, u32>,
        pub Multisig_total_txs: TransactionID,
        pub Multisig_tx_confirmations: Map<TransactionID, u32>,
        pub Multisig_tx_confirmed_by: Map<(TransactionID, ContractAddress), bool>,
        pub Multisig_tx_executed: Map<TransactionID, bool>,
        pub Multisig_tx_calls_len: Map<TransactionID, u32>,
        pub Multisig_tx_call_info: Map<(TransactionID, u32), StorableCallInfo>,
        pub Multisig_tx_call_calldata: Map<(TransactionID, u32, u32), felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SignerAdded: SignerAdded,
        SignerRemoved: SignerRemoved,
        ThresholdUpdated: ThresholdUpdated,
        TransactionSubmitted: TransactionSubmitted,
        TransactionConfirmed: TransactionConfirmed,
        TransactionExecuted: TransactionExecuted,
        ConfirmationRevoked: ConfirmationRevoked,
        ExecutionFailed: ExecutionFailed
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

    #[derive(Drop, starknet::Event)]
    pub struct ExecutionFailed {
        #[key]
        pub id: TransactionID
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
    pub struct ThresholdUpdated {
        pub old_threshold: u32,
        pub new_threshold: u32
    }

    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Multisig: unauthorized';
        pub const NOT_A_SIGNER: felt252 = 'Multisig: not a signer';
        pub const ALREADY_A_SIGNER: felt252 = 'Multisig: already a signer';
        pub const ALREADY_CONFIRMED: felt252 = 'Multisig: already confirmed';
        pub const HAS_NOT_CONFIRMED: felt252 = 'Multisig: has not confirmed';
        pub const TX_NOT_FOUND: felt252 = 'Multisig: tx not found';
        pub const TX_NOT_CONFIRMED: felt252 = 'Multisig: tx not confirmed';
        pub const TX_ALREADY_EXECUTED: felt252 = 'Multisig: tx already executed';
        pub const EMPTY_SIGNERS_LIST: felt252 = 'Multisig: empty signers list';
        pub const ZERO_THRESHOLD: felt252 = 'Multisig: threshold is zero';
        pub const THRESHOLD_TOO_HIGH: felt252 = 'Multisig: threshold > signers';
    }

    #[embeddable_as(MultisigImpl)]
    impl Multisig<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of IMultisig<ComponentState<TContractState>> {
        fn is_confirmed(self: @ComponentState<TContractState>, id: TransactionID) -> bool {
            match self.resolve_tx_status(id) {
                TransactionStatus::NotFound => false,
                TransactionStatus::Submitted => false,
                TransactionStatus::Confirmed => true,
                TransactionStatus::Executed => true
            }
        }

        fn is_executed(self: @ComponentState<TContractState>, id: TransactionID) -> bool {
            self.Multisig_tx_executed.read(id)
        }

        fn get_transaction_status(
            self: @ComponentState<TContractState>, id: TransactionID
        ) -> TransactionStatus {
            self.resolve_tx_status(id)
        }

        fn get_transaction_calls(
            self: @ComponentState<TContractState>, id: TransactionID
        ) -> Span<Call> {
            self.load_tx_calls(id)
        }

        fn get_threshold(self: @ComponentState<TContractState>) -> u32 {
            self.Multisig_threshold.read()
        }

        fn is_signer(self: @ComponentState<TContractState>, signer: ContractAddress) -> bool {
            self.Multisig_is_signer.read(signer)
        }

        fn add_signers(
            ref self: ComponentState<TContractState>,
            new_threshold: u32,
            signers_to_add: Span<ContractAddress>
        ) {
            self.assert_only_self();
            self._add_signers(new_threshold, signers_to_add);
        }

        fn remove_signers(
            ref self: ComponentState<TContractState>,
            new_threshold: u32,
            signers_to_remove: Span<ContractAddress>
        ) {
            self.assert_only_self();
            self._remove_signers(new_threshold, signers_to_remove);
        }

        fn replace_signer(
            ref self: ComponentState<TContractState>,
            signer_to_remove: ContractAddress,
            signer_to_add: ContractAddress
        ) {
            self.assert_only_self();
            self._replace_signer(signer_to_remove, signer_to_add);
        }

        fn change_threshold(ref self: ComponentState<TContractState>, new_threshold: u32) {
            self.assert_only_self();
            self._change_threshold(new_threshold);
        }

        fn submit_transaction(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            selector: felt252,
            calldata: Span<felt252>
        ) -> TransactionID {
            let caller = get_caller_address();
            self.assert_one_of_signers(caller);

            let id = self.emit_new_tx_id();
            let call = Call { to, selector, calldata };
            self.store_tx_calls(id, array![call].span());
            self.emit(TransactionSubmitted { id, signer: caller });

            id
        }

        fn submit_transaction_batch(
            ref self: ComponentState<TContractState>, calls: Span<Call>
        ) -> TransactionID {
            let caller = get_caller_address();
            self.assert_one_of_signers(caller);

            let id = self.emit_new_tx_id();
            self.store_tx_calls(id, calls);
            self.emit(TransactionSubmitted { id, signer: caller });

            id
        }

        fn confirm_transaction(ref self: ComponentState<TContractState>, id: TransactionID) {
            let caller = get_caller_address();
            self.assert_one_of_signers(caller);
            assert(!self.Multisig_tx_confirmed_by.read((id, caller)), Errors::ALREADY_CONFIRMED);
            assert(!self.Multisig_tx_executed.read(id), Errors::TX_ALREADY_EXECUTED);

            let total_confirmations = 1 + self.Multisig_tx_confirmations.read(id);
            self.Multisig_tx_confirmations.write(id, total_confirmations);
            self.Multisig_tx_confirmed_by.write((id, caller), true);

            self.emit(TransactionConfirmed { id, signer: caller, total_confirmations });
        }

        fn revoke_confirmation(ref self: ComponentState<TContractState>, id: TransactionID) {
            let caller = get_caller_address();
            self.assert_one_of_signers(caller);
            assert(self.Multisig_tx_confirmed_by.read((id, caller)), Errors::HAS_NOT_CONFIRMED);
            assert(!self.Multisig_tx_executed.read(id), Errors::TX_ALREADY_EXECUTED);

            let total_confirmations = self.Multisig_tx_confirmations.read(id) - 1;
            self.Multisig_tx_confirmations.write(id, total_confirmations);
            self.Multisig_tx_confirmed_by.write((id, caller), false);

            self.emit(ConfirmationRevoked { id, signer: caller, total_confirmations });
        }

        fn execute_transaction(ref self: ComponentState<TContractState>, id: TransactionID) {
            let caller = get_caller_address();
            self.assert_one_of_signers(caller);

            match self.resolve_tx_status(id) {
                TransactionStatus::NotFound => panic_with_felt252(Errors::TX_NOT_FOUND),
                TransactionStatus::Submitted => panic_with_felt252(Errors::TX_NOT_CONFIRMED),
                TransactionStatus::Executed => panic_with_felt252(Errors::TX_ALREADY_EXECUTED),
                TransactionStatus::Confirmed => {
                    self.Multisig_tx_executed.write(id, true);
                    let tx_calls = self.load_tx_calls(id);
                    for call in tx_calls {
                        let Call { to, selector, calldata } = *call;
                        call_contract_syscall(to, selector, calldata).unwrap_syscall();
                    };
                    self.emit(TransactionExecuted { id });
                }
            };
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>, threshold: u32, signers: Span<ContractAddress>
        ) {
            self._add_signers(threshold, signers);
        }

        fn emit_new_tx_id(ref self: ComponentState<TContractState>) -> TransactionID {
            let new_tx_id = self.Multisig_total_txs.read();
            self.Multisig_total_txs.write(new_tx_id + 1);
            new_tx_id
        }

        fn resolve_tx_status(
            self: @ComponentState<TContractState>, id: TransactionID
        ) -> TransactionStatus {
            if id >= self.Multisig_total_txs.read() {
                TransactionStatus::NotFound
            } else if self.Multisig_tx_executed.read(id) {
                TransactionStatus::Executed
            } else {
                let confirmations = self.Multisig_tx_confirmations.read(id);
                let is_confirmed = confirmations >= self.Multisig_threshold.read();
                if is_confirmed {
                    TransactionStatus::Confirmed
                } else {
                    TransactionStatus::Submitted
                }
            }
        }

        fn store_tx_calls(
            ref self: ComponentState<TContractState>, id: TransactionID, calls: Span<Call>
        ) {
            self.Multisig_tx_calls_len.write(id, calls.len());
            let mut call_index = 0;
            for call in calls {
                let Call { to, selector, calldata } = *call;
                let call_info = StorableCallInfo { to, selector, calldata_len: calldata.len() };
                self.Multisig_tx_call_info.write((id, call_index), call_info);
                let mut calldata_index = 0;
                for val in calldata {
                    self.Multisig_tx_call_calldata.write((id, call_index, calldata_index), *val);
                    calldata_index += 1;
                };
                call_index += 1;
            };
        }

        fn load_tx_calls(self: @ComponentState<TContractState>, id: TransactionID) -> Span<Call> {
            let calls_len = self.Multisig_tx_calls_len.read(id);
            let mut call_index = 0;
            let mut result = array![];
            while call_index < calls_len {
                let call_info = self.Multisig_tx_call_info.read((id, call_index));
                let StorableCallInfo { to, selector, calldata_len } = call_info;
                let mut calldata_index = 0;
                let mut calldata = array![];
                while calldata_index < calldata_len {
                    let val = self.Multisig_tx_call_calldata.read((id, call_index, calldata_index));
                    calldata.append(val);
                    calldata_index += 1;
                };
                result.append(Call { to, selector, calldata: calldata.span() });
                call_index += 1;
            };
            result.span()
        }

        fn _add_signers(
            ref self: ComponentState<TContractState>,
            new_threshold: u32,
            signers_to_add: Span<ContractAddress>
        ) {
            assert(!signers_to_add.is_empty(), Errors::EMPTY_SIGNERS_LIST);

            let mut current_signers_count = self.Multisig_signers_count.read();
            for signer in signers_to_add {
                let signer_to_add = *signer;
                assert(!self.Multisig_is_signer.read(signer_to_add), Errors::ALREADY_A_SIGNER);

                let index = current_signers_count;
                self.Multisig_is_signer.write(signer_to_add, true);
                self.Multisig_signers_by_index.write(index, signer_to_add);
                self.Multisig_signers_indices.write(signer_to_add, index);
                self.emit(SignerAdded { signer: signer_to_add });

                current_signers_count += 1;
            };
            self.Multisig_signers_count.write(current_signers_count);

            self._change_threshold(new_threshold);
        }

        fn _remove_signers(
            ref self: ComponentState<TContractState>,
            new_threshold: u32,
            signers_to_remove: Span<ContractAddress>
        ) {
            assert(!signers_to_remove.is_empty(), Errors::EMPTY_SIGNERS_LIST);

            let mut current_signers_count = self.Multisig_signers_count.read();
            for signer in signers_to_remove {
                let signer_to_remove = *signer;
                assert(self.Multisig_is_signer.read(signer_to_remove), Errors::NOT_A_SIGNER);

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

            self._change_threshold(new_threshold);
        }

        fn _replace_signer(
            ref self: ComponentState<TContractState>,
            signer_to_remove: ContractAddress,
            signer_to_add: ContractAddress
        ) {
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

        fn _change_threshold(ref self: ComponentState<TContractState>, new_threshold: u32) {
            assert(new_threshold.is_non_zero(), Errors::ZERO_THRESHOLD);
            assert(new_threshold <= self.Multisig_signers_count.read(), Errors::THRESHOLD_TOO_HIGH);

            let old_threshold = self.Multisig_threshold.read();
            if new_threshold != old_threshold {
                self.Multisig_threshold.write(new_threshold);
                self.emit(ThresholdUpdated { old_threshold, new_threshold });
            }
        }

        fn assert_one_of_signers(self: @ComponentState<TContractState>, caller: ContractAddress) {
            assert(self.Multisig_is_signer.read(caller), Errors::NOT_A_SIGNER);
        }

        fn assert_only_self(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            let self = get_contract_address();
            assert(self == caller, Errors::UNAUTHORIZED);
        }
    }
}
