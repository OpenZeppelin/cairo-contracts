use starknet::account::Call;
use crate::mocks::observer::CallInfo;

#[starknet::interface]
pub trait ILegacyAccount<TState> {
    fn __execute__(ref self: TState, calls: Array<Call>);
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::contract(account)]
pub mod LegacyAccountMock {
    use core::num::traits::Zero;
    use starknet::account::Call;
    use openzeppelin_account::utils::is_valid_stark_signature;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, SyscallResultTrait};
    use crate::mocks::observer::{ObserverComponent, CallInfo};
    use crate::mocks::observer::ObserverComponent::InternalTrait as ObserverInternalTrait;

    component!(path: ObserverComponent, storage: observer, event: ObserverEvent);

    #[abi(embed_v0)]
    impl ObserverImpl = ObserverComponent::ObserverImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ObserverEvent: ObserverComponent::Event,
    }

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub observer: ObserverComponent::Storage,
        pub public_key: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.public_key.write(public_key);
    }

    #[abi(embed_v0)]
    pub impl LegacyAccountImpl of super::ILegacyAccount<ContractState> {
        fn __execute__(ref self: ContractState, calls: Array<Call>) {
            // Check sender
            let sender = starknet::get_caller_address();
            assert(sender.is_zero(), 'Account: invalid caller');
            // Check tx version
            let tx_version = starknet::get_tx_info().unbox().version;
            assert(tx_version == 0, 'Account: invalid tx version');
            // Validate transaction
            // self.validate_transaction();
            // Execute calls
            for call in calls.span() {
                self.execute_single_call(call);
            }
            // Store event
            self.observer.store_call_info();
            // Emit event
            self.observer.emit_external_call_event();
        }

        fn __validate__(self: @ContractState, calls: Array<Call>) -> felt252 {
            self.validate_transaction()
        }

        fn is_valid_signature(self: @ContractState, hash: felt252, signature: Array<felt252>) -> felt252 {
            if self._is_valid_signature(hash, signature.span()) {
                starknet::VALIDATED
            } else {
                0
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn validate_transaction(self: @ContractState) -> felt252 {
            let tx_info = starknet::get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(self._is_valid_signature(tx_hash, signature), 'Account: invalid signature');
            starknet::VALIDATED
        }

        fn execute_single_call(self: @ContractState, call: @Call) {
            let Call { to, selector, calldata } = *call;
            starknet::syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall();
        }

        fn _is_valid_signature(self: @ContractState, hash: felt252, signature: Span<felt252>) -> bool {
            let public_key = self.public_key.read();
            is_valid_stark_signature(hash, public_key, signature)
        }
    }
}
