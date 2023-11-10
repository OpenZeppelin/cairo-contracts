#[starknet::contract]
mod InitializableMock {
    use openzeppelin::security::initializable::InitializableComponent;

    component!(path: InitializableComponent, storage: initializable, event: InitializableEvent);

    #[abi(embed_v0)]
    impl InitializableImpl =
        InitializableComponent::InitializableImpl<ContractState>;

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
