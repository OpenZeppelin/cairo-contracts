#[starknet::interface]
pub trait ICounter<TState> {
    fn get_current_value(self: @TState) -> u64;
    fn increase_by(ref self: TState, amount: u64);
}

#[starknet::contract]
pub mod CounterMock {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::mocks::observer::ObserverComponent;
    use crate::mocks::observer::ObserverComponent::InternalTrait;

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
        pub value: u64,
    }

    #[abi(embed_v0)]
    impl CounterImpl of super::ICounter<ContractState> {
        fn get_current_value(self: @ContractState) -> u64 {
            self.value.read()
        }

        fn increase_by(ref self: ContractState, amount: u64) {
            self.value.write(self.value.read() + amount);
            self.observer.store_call_info();
            self.observer.emit_external_call_event();
        }
    }
}
