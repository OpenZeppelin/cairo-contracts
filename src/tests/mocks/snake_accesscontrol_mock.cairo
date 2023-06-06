#[contract]
mod SnakeAccessControlMock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::access::accesscontrol::AccessControl;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::utils::serde::SpanSerde;

    #[constructor]
    fn constructor(admin: ContractAddress) {
        AccessControl::initializer();
        AccessControl::_grant_role(DEFAULT_ADMIN_ROLE, admin);
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        AccessControl::supports_interface(interface_id)
    }

    #[view]
    fn has_role(role: felt252, account: ContractAddress) -> bool {
        AccessControl::has_role(role, account)
    }

    #[view]
    fn get_role_admin(role: felt252) -> felt252 {
        AccessControl::get_role_admin(role)
    }

    #[external]
    fn grant_role(role: felt252, account: ContractAddress) {
        AccessControl::grant_role(role, account);
    }

    #[external]
    fn revoke_role(role: felt252, account: ContractAddress) {
        AccessControl::revoke_role(role, account);
    }

    #[external]
    fn renounce_role(role: felt252, account: ContractAddress) {
        AccessControl::renounce_role(role, account);
    }
}
