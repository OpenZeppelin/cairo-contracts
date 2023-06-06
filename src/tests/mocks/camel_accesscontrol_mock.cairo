#[contract]
mod CamelAccessControlMock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::access::accesscontrol::AccessControl;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

    #[constructor]
    fn constructor(admin: ContractAddress) {
        AccessControl::initializer();
        AccessControl::_grant_role(DEFAULT_ADMIN_ROLE, admin);
    }

    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        AccessControl::supportsInterface(interfaceId)
    }

    #[view]
    fn hasRole(role: felt252, account: ContractAddress) -> bool {
        AccessControl::hasRole(role, account)
    }

    #[view]
    fn getRoleAdmin(role: felt252) -> felt252 {
        AccessControl::getRoleAdmin(role)
    }

    #[external]
    fn grantRole(role: felt252, account: ContractAddress) {
        AccessControl::grantRole(role, account);
    }

    #[external]
    fn revokeRole(role: felt252, account: ContractAddress) {
        AccessControl::revokeRole(role, account);
    }

    #[external]
    fn renounceRole(role: felt252, account: ContractAddress) {
        AccessControl::renounceRole(role, account);
    }
}
