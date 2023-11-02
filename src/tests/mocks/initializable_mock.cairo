#[starknet::contract]
mod InitializableMock {
    use openzeppelin::security::initializable::InitializableComponent;

    component!(path: InitializableComponent, storage: initializable, event: InitializableEvent);

    impl InternalImpl = InitializableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        initializable: InitializableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        InitializableEvent: InitializableComponent::Event
    }
}
