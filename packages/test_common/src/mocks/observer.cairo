use starknet::ContractAddress;

#[derive(Drop, Copy, Debug, PartialEq, Serde, starknet::Store, starknet::Event)]
pub struct CallInfo {
    pub caller: ContractAddress,
    pub tx_version: felt252,
    pub chain_id: felt252,
    pub tx_hash: felt252,
}

#[starknet::interface]
pub trait IObserver<TState> {
    fn get_all_calls(self: @TState) -> Array<CallInfo>;
}

#[starknet::component]
pub mod ObserverComponent {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::CallInfo;

    #[storage]
    pub struct Storage {
        pub calls_len: u32,
        pub calls: Map<u32, CallInfo>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        ExternalCall: CallInfo,
    }

    #[embeddable_as(ObserverImpl)]
    pub impl Observer<
        TContractState, +HasComponent<TContractState>,
    > of super::IObserver<ComponentState<TContractState>> {
        fn get_all_calls(self: @ComponentState<TContractState>) -> Array<CallInfo> {
            let len = self.calls_len.read();
            let mut calls = array![];
            for i in 0..len {
                calls.append(self.calls.read(i));
            }
            calls
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn store_call_info(ref self: ComponentState<TContractState>) {
            let call_info = self.prepare_call_info();
            let current_len = self.calls_len.read();
            self.calls_len.write(current_len + 1);
            self.calls.write(current_len, call_info);
        }

        fn emit_external_call_event(ref self: ComponentState<TContractState>) {
            let call_info = self.prepare_call_info();
            self.emit(call_info);
        }

        fn prepare_call_info(self: @ComponentState<TContractState>) -> CallInfo {
            let tx_info = starknet::get_tx_info().unbox();
            CallInfo {
                caller: starknet::get_caller_address(),
                tx_version: tx_info.version,
                chain_id: tx_info.chain_id,
                tx_hash: tx_info.transaction_hash,
            }
        }
    }
}
