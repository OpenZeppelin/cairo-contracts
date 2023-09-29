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
