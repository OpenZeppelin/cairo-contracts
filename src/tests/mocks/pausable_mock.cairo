#[starknet::contract]
mod PausableMock {
    use openzeppelin::security::pausable::Pausable as pausable_comp;

    component!(path: pausable_comp, storage: pausable, event: PausableEvent);

    #[abi(embed_v0)]
    impl PausableImpl = pausable_comp::PausableImpl<ContractState>;
    impl InternalImpl = pausable_comp::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        pausable: pausable_comp::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PausableEvent: pausable_comp::Event
    }
}
