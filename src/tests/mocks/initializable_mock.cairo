#[starknet::contract]
mod InitializableMock {
    use openzeppelin::security::Initializable as initializable_component;

    component!(path: initializable_component, storage: initializable, event: InitializableEvent);

    #[abi(embed_v0)]
    impl InitializableImpl =
        initializable_component::InitializableImpl<ContractState>;
    impl InternalImpl = initializable_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        initializable: initializable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        InitializableEvent: initializable_component::Event
    }
}
