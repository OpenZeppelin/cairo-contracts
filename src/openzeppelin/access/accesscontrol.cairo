use starknet::ContractAddress;

const DEFAULT_ADMIN_ROLE: felt252 = 0;
const IACCESSCONTROL_ID: u32 = 0x7965db0b_u32;

#[abi]
trait IAccessControl {
    fn has_role(role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(role: felt252) -> felt252;
    fn grant_role(role: felt252, account: ContractAddress);
    fn revoke_role(role: felt252, account: ContractAddress);
    fn renounce_role(role: felt252, account: ContractAddress);
}

#[contract]
mod AccessControl {
    use super::IAccessControl;
    use super::DEFAULT_ADMIN_ROLE;
    use super::IACCESSCONTROL_ID;
    use openzeppelin::introspection::erc165::ERC165;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    struct Storage {
        role_admin: LegacyMap<felt252, felt252>,
        role_members: LegacyMap<(felt252, ContractAddress), bool>,
    }

    /// Emitted when `account` is granted `role`.
    ///
    /// `sender` is the account that originated the contract call, an admin role
    /// bearer (except if `_grant_role` is called during initialization from the constructor).
    #[event]
    fn RoleGranted(role: felt252, account: ContractAddress, sender: ContractAddress) {}

    /// Emitted when `account` is revoked `role`.
    ///
    /// `sender` is the account that originated the contract call:
    ///   - If using `revoke_role`, it is the admin role bearer.
    ///   - If using `renounce_role`, it is the role bearer (i.e. `account`).
    #[event]
    fn RoleRevoked(role: felt252, account: ContractAddress, sender: ContractAddress) {}

    /// Emitted when `new_admin_role` is set as `role`'s admin role, replacing `previous_admin_role`
    ///
    /// `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
    /// {RoleAdminChanged} not being emitted signaling this.
    #[event]
    fn RoleAdminChanged(role: felt252, previous_admin_role: felt252, new_admin_role: felt252) {}

    impl AccessControlImpl of IAccessControl {
        fn has_role(role: felt252, account: ContractAddress) -> bool {
            role_members::read((role, account))
        }

        fn get_role_admin(role: felt252) -> felt252 {
            role_admin::read(role)
        }

        fn grant_role(role: felt252, account: ContractAddress) {
            let admin = get_role_admin(role);
            assert_only_role(admin);
            _grant_role(role, account);
        }

        fn revoke_role(role: felt252, account: ContractAddress) {
            let admin: felt252 = get_role_admin(role);
            assert_only_role(admin);
            _revoke_role(role, account);
        }

        fn renounce_role(role: felt252, account: ContractAddress) {
            let caller: ContractAddress = get_caller_address();
            assert(caller == account, 'Can only renounce role for self');
            _revoke_role(role, account);
        }
    }

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        ERC165::supports_interface(interface_id)
    }

    #[view]
    fn has_role(role: felt252, account: ContractAddress) -> bool {
        AccessControlImpl::has_role(role, account)
    }

    #[view]
    fn get_role_admin(role: felt252) -> felt252 {
        AccessControlImpl::get_role_admin(role)
    }

    #[external]
    fn grant_role(role: felt252, account: ContractAddress) {
        AccessControlImpl::grant_role(role, account);
    }

    #[external]
    fn revoke_role(role: felt252, account: ContractAddress) {
        AccessControlImpl::revoke_role(role, account);
    }

    #[external]
    fn renounce_role(role: felt252, account: ContractAddress) {
        AccessControlImpl::renounce_role(role, account);
    }

    #[internal]
    fn initializer() {
        ERC165::register_interface(IACCESSCONTROL_ID);
    }

    #[internal]
    fn assert_only_role(role: felt252) {
        let caller: ContractAddress = get_caller_address();
        let authorized: bool = has_role(role, caller);
        assert(authorized, 'Caller is missing role');
    }

    //
    // WARNING
    // The following internal methods are unprotected and should not be used
    // outside of a contract's constructor.
    //

    #[internal]
    fn _grant_role(role: felt252, account: ContractAddress) {
        if !has_role(role, account) {
            let caller: ContractAddress = get_caller_address();
            role_members::write((role, account), true);
            RoleGranted(role, account, caller);
        }
    }

    #[internal]
    fn _revoke_role(role: felt252, account: ContractAddress) {
        if has_role(role, account) {
            let caller: ContractAddress = get_caller_address();
            role_members::write((role, account), false);
            RoleRevoked(role, account, caller);
        }
    }

    #[internal]
    fn _set_role_admin(role: felt252, admin_role: felt252) {
        let previous_admin_role: felt252 = get_role_admin(role);
        role_admin::write(role, admin_role);
        RoleAdminChanged(role, previous_admin_role, admin_role);
    }
}
