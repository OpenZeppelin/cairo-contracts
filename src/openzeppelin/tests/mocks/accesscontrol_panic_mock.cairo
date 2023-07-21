// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// false for bool

#[contract]
mod SnakeAccessControlPanicMock {
    use starknet::ContractAddress;

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[view]
    fn has_role(role: felt252, account: ContractAddress) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[view]
    fn get_role_admin(role: felt252) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external]
    fn grant_role(role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn revoke_role(role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn renounce_role(role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }
}

#[contract]
mod CamelAccessControlPanicMock {
    use starknet::ContractAddress;

    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[view]
    fn hasRole(role: felt252, account: ContractAddress) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[view]
    fn getRoleAdmin(role: felt252) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external]
    fn grantRole(role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn revokeRole(role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn renounceRole(role: felt252, account: ContractAddress) {
        panic_with_felt252('Some error');
    }
}
