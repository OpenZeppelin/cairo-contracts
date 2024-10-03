#[starknet::contract]
pub mod DualCaseOwnableMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage
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
pub mod SnakeOwnableMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage
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
pub mod CamelOwnableMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_access::ownable::interface::IOwnable;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage
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

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn owner(self: @ContractState) -> ContractAddress {
            self.ownable.owner()
        }
    }
}

#[starknet::contract]
pub mod SnakeOwnablePanicMock {
    use core::num::traits::Zero;
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn owner(self: @ContractState) -> ContractAddress {
            panic!("Some error");
            Zero::zero()
        }

        #[external(v0)]
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            panic!("Some error");
        }

        #[external(v0)]
        fn renounce_ownership(ref self: ContractState) {
            panic!("Some error");
        }
    }
}

#[starknet::contract]
pub mod CamelOwnablePanicMock {
    use core::num::traits::Zero;
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn owner(self: @ContractState) -> ContractAddress {
            panic!("Some error");
            Zero::zero()
        }

        #[external(v0)]
        fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
            panic!("Some error");
        }

        #[external(v0)]
        fn renounceOwnership(ref self: ContractState) {
            panic!("Some error");
        }
    }
}

#[starknet::contract]
pub mod DualCaseTwoStepOwnableMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableTwoStepMixinImpl =
        OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
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
