use openzeppelin::access::ownable::Ownable;

#[starknet::contract]
mod DualCaseOwnableMock {
    use openzeppelin::access::ownable::Ownable as ownable_component;
    use starknet::ContractAddress;
    use super::Ownable;

    component!(path: ownable_component, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = ownable_component::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        ownable_component::OwnableCamelOnlyImpl<ContractState>;
    impl InternalImpl = ownable_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnableEvent: ownable_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}

#[starknet::contract]
mod SnakeOwnableMock {
    use openzeppelin::access::ownable::Ownable as ownable_component;
    use starknet::ContractAddress;
    use super::Ownable;

    component!(path: ownable_component, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = ownable_component::OwnableImpl<ContractState>;
    impl InternalImpl = ownable_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnableEvent: ownable_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}

#[starknet::contract]
mod CamelOwnableMock {
    use openzeppelin::access::ownable::Ownable as ownable_component;
    use starknet::ContractAddress;
    use super::Ownable;

    component!(path: ownable_component, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        ownable_component::OwnableCamelOnlyImpl<ContractState>;
    impl InternalImpl = ownable_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnableEvent: ownable_component::Event
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
