#[starknet::contract]
mod InitializableMock {
    use openzeppelin::security::initializable::Initializable as initializable_comp;

    component!(path: initializable_comp, storage: initializable, event: InitializableEvent);
    impl InternalImpl = initializable_comp::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        initializable: initializable_comp::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        InitializableEvent: initializable_comp::Event
    }
}
