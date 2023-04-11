use starknet::ContractAddress;

#[abi]
trait IAccessControl {
    fn has_role(role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(role: felt252) -> felt252;
    fn grant_role(role: felt252, account: ContractAddress);
    fn revoke_role(role: felt252, account: ContractAddress);
    fn renounce_role(role: felt252, account: ContractAddress);
}

#[abi]
trait IERC165 {
    fn supports_interface() -> bool;
}

#[contract]
mod AccessControl {
    use super::IAccessControl;
    use super::IERC165;

    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::contract_address_const;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    struct Storage {
        role_admin: LegacyMap<felt252, felt252>,
        role_member: LegacyMap<(felt252, ContractAddress), bool>,
    }

    const DEFAULT_ADMIN_ROLE: felt252 = 0x00;

    #[event]
    fn RoleGranted(role: felt252, account: ContractAddress, sender: ContractAddress) {}

    #[event]
    fn RoleRevoked(role: felt252, account: ContractAddress, sender: ContractAddress) {}

    #[event]
    fn RoleAdminChanged(role: felt252, previous_admin_role: felt252, new_admin_role: felt252) {}

    fn initializer() {}

    fn assert_only_role(role: felt252) {
        let caller: ContractAddress = get_caller_address();
        let authorized: bool = has_role(role, caller);
        assert(authorized, 'Caller is missing role');
    }

    fn has_role(role: felt252, user: ContractAddress) -> bool {
        role_member::read((role, user))
    }

    fn get_role_admin(role: felt252) -> felt252 {
        role_admin::read(role)
    }

    fn grant_role(role: felt252, user: ContractAddress) {
        let admin: felt252 = get_role_admin(role);
        assert_only_role(admin);
        _grant_role(role, user);
    }

    fn revoke_role(role: felt252, user: ContractAddress) {
        let admin: felt252 = get_role_admin(role);
        assert_only_role(admin);
        _revoke_role(role, user);
    }

    fn renounce_role(role: felt252, user: ContractAddress) {
        let caller: ContractAddress = get_caller_address();
        assert(caller == user, 'Can only renounce role for self');
        _revoke_role(role, user);
    }

    //
    // Unprotected
    //

    fn _grant_role(role: felt252, user: ContractAddress) {
        if !has_role(role, user) {
            let caller: ContractAddress = get_caller_address();
            role_member::write((role, user), true);
            RoleGranted(role, user, caller);
        }
    }

    fn _revoke_role(role: felt252, user: ContractAddress) {
        if has_role(role, user) {
            let caller: ContractAddress = get_caller_address();
            role_member::write((role, user), false);
            RoleRevoked(role, user, caller);
        }
    }

    fn _set_role_admin(role: felt252, admin_role: felt252) {
        let previous_admin_role: felt252 = get_role_admin(role);
        role_admin::write(role, admin_role);
        RoleAdminChanged(role, previous_admin_role, admin_role);
    }
}
