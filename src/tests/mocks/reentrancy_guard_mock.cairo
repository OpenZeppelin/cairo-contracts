#[starknet::contract]
mod ReentrancyGuardMock {
    use openzeppelin::security::reentrancyguard::ReentrancyGuard as reentrancy_guard_comp;

    component!(path: reentrancy_guard_comp, storage: reentrancy_guard, event: ReentrancyGuardEvent);
    impl InternalImpl = reentrancy_guard_comp::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        reentrancy_guard: reentrancy_guard_comp::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ReentrancyGuardEvent: reentrancy_guard_comp::Event
    }
}
