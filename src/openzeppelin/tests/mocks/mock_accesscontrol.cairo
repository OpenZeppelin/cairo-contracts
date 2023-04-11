#[contract]
mod MockAccessControl {
    use openzeppelin::access::accesscontrol::AccessControl;
    use starknet::ContractAddress;

    #[constructor]
    fn constructor(admin: ContractAddress) {
        AccessControl::initializer();
        AccessControl::_grant_role(AccessControl::DEFAULT_ADMIN_ROLE, admin);
    }

    #[view]
    fn has_role(role: felt252, account: ContractAddress) -> bool {
        AccessControl::has_role(role, account)
    }

    #[view]
    fn get_role_admin(role:felt252) -> felt252 {
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

    // ONLY FOR MOCKS. DON'T USE IN PRODUCTION
    #[external]
    fn set_role_admin(role: felt252, admin: felt252) {
        AccessControl::_set_role_admin(role, admin);
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        // ERC165 FIX ME
        true
    }
}
