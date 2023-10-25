#[starknet::contract]
mod DualCaseAccessControlMock {
    use openzeppelin::access::accesscontrol::AccessControl as accesscontrol_component;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::ContractAddress;

    component!(path: accesscontrol_component, storage: accesscontrol, event: AccessControlEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        accesscontrol_component::AccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlCamelImpl =
        accesscontrol_component::AccessControlCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;

    impl AccessControlInternalImpl = accesscontrol_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: accesscontrol_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: accesscontrol_component::Event,
        #[flat]
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
    }
}

#[starknet::contract]
mod SnakeAccessControlMock {
    use openzeppelin::access::accesscontrol::AccessControl as accesscontrol_component;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::ContractAddress;

    component!(path: accesscontrol_component, storage: accesscontrol, event: AccessControlEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        accesscontrol_component::AccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    impl AccessControlInternalImpl = accesscontrol_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: accesscontrol_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: accesscontrol_component::Event,
        #[flat]
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
    }
}

#[starknet::contract]
mod CamelAccessControlMock {
    use openzeppelin::access::accesscontrol::AccessControl as accesscontrol_component;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::ContractAddress;

    component!(path: accesscontrol_component, storage: accesscontrol, event: AccessControlEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccessControlCamelImpl =
        accesscontrol_component::AccessControlCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;

    impl AccessControlInternalImpl = accesscontrol_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: accesscontrol_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: accesscontrol_component::Event,
        #[flat]
        SRC5Event: src5_component::Event
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
mod SnakeAccessControlPanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external(v0)]
    fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[starknet::contract]
mod CamelAccessControlPanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn hasRole(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external(v0)]
    fn getRoleAdmin(self: @ContractState, role: felt252) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn grantRole(ref self: ContractState, role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn revokeRole(ref self: ContractState, role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn renounceRole(ref self: ContractState, role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}
