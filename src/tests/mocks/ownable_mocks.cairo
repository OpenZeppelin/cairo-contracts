#[starknet::contract]
mod DualCaseOwnableMock {
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}

#[starknet::contract]
mod SnakeOwnableMock {
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}

#[starknet::contract]
mod CamelOwnableMock {
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        self.ownable.Ownable_owner.read()
    }
}

#[starknet::contract]
mod SnakeOwnablePanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external(v0)]
    fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn renounce_ownership(ref self: ContractState) {
        panic_with_felt252('Some error');
    }
}

#[starknet::contract]
mod CamelOwnablePanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external(v0)]
    fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn renounceOwnership(ref self: ContractState) {
        panic_with_felt252('Some error');
    }
}
