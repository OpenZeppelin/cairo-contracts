#[starknet::contract]
pub mod DualCaseAccessControlMock {
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // AccessControlMixin
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
    }
}

#[starknet::contract]
pub mod SnakeAccessControlMock {
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // SCR5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
    }
}

#[starknet::contract]
pub mod CamelAccessControlMock {
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlCamelImpl =
        AccessControlComponent::AccessControlCamelImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // SCR5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;


    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
    }
}

// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// false for bool

#[starknet::contract]
pub mod SnakeAccessControlPanicMock {
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
            panic!("Some error");
            3
        }

        #[external(v0)]
        fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic!("Some error");
        }

        #[external(v0)]
        fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic!("Some error");
        }

        #[external(v0)]
        fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic!("Some error");
        }

        #[external(v0)]
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            panic!("Some error");
            false
        }
    }
}

#[starknet::contract]
pub mod CamelAccessControlPanicMock {
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn hasRole(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn getRoleAdmin(self: @ContractState, role: felt252) -> felt252 {
            panic!("Some error");
            3
        }

        #[external(v0)]
        fn grantRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic!("Some error");
        }

        #[external(v0)]
        fn revokeRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic!("Some error");
        }

        #[external(v0)]
        fn renounceRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic!("Some error");
        }

        #[external(v0)]
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            panic!("Some error");
            false
        }
    }
}
