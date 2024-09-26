#[starknet::contract]
pub(crate) mod InitializableMock {
    use crate::initializable::InitializableComponent;

    component!(path: InitializableComponent, storage: initializable, event: InitializableEvent);

    #[abi(embed_v0)]
    impl InitializableImpl =
        InitializableComponent::InitializableImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub initializable: InitializableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        InitializableEvent: InitializableComponent::Event
    }
}
