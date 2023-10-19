#[starknet::contract]
mod PausableMock {
    use openzeppelin::security::Pausable as pausable_component;

    component!(path: pausable_component, storage: pausable, event: PausableEvent);

    #[abi(embed_v0)]
    impl PausableImpl = pausable_component::PausableImpl<ContractState>;
    impl InternalImpl = pausable_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        pausable: pausable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PausableEvent: pausable_component::Event
    }
}
