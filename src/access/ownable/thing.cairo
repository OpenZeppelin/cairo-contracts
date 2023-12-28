#[starknet::contract]
mod DualCaseOwnableMock {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::mixins::OwnableDual;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: OwnableDual, storage: ownabledual, event: OwnableDualEvent);

    #[abi(embed_v0)]
    impl OwnableDualImpl = OwnableDual::OwnableDualImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        ownabledual: OwnableDual::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        OwnableDualEvent: OwnableDual::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}
