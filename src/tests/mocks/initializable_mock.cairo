#[starknet::contract]
mod InitializableMock {
    use openzeppelin::security::initializable::Initializable as initializable_component;

    component!(path: initializable_component, storage: initializable, event: InitializableEvent);

    impl InternalImpl = initializable_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        initializable: initializable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        InitializableEvent: initializable_component::Event
    }
}
