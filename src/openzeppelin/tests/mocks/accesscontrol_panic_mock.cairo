// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// false for bool

#[starknet::contract]
mod SnakeAccessControlPanicMock {
    use starknet::ContractAddress;
    use openzeppelin::introspection::interface::ISRC5;
    use openzeppelin::access::accesscontrol::interface;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            panic_with_felt252('Some error');
            false
        }
    }

    #[external(v0)]
    impl AccessControlImpl of interface::IAccessControl<ContractState> {
        fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            panic_with_felt252('Some error');
            false
        }

        fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
            panic_with_felt252('Some error');
            3
        }

        fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic_with_felt252('Some error');
        }

        fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic_with_felt252('Some error');
        }

        fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic_with_felt252('Some error');
        }
    }
}

#[starknet::contract]
mod CamelAccessControlPanicMock {
    use starknet::ContractAddress;
    use openzeppelin::introspection::interface::ISRC5Camel;
    use openzeppelin::access::accesscontrol::interface;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl SRC5CamelImpl of ISRC5Camel<ContractState> {
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            panic_with_felt252('Some error');
            false
        }
    }

    #[external(v0)]
    impl AccessControlCamelImpl of interface::IAccessControlCamel<ContractState> {
        fn hasRole(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            panic_with_felt252('Some error');
            false
        }

        fn getRoleAdmin(self: @ContractState, role: felt252) -> felt252 {
            panic_with_felt252('Some error');
            3
        }

        fn grantRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic_with_felt252('Some error');
        }

        fn revokeRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic_with_felt252('Some error');
        }

        fn renounceRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            panic_with_felt252('Some error');
        }
    }
}
