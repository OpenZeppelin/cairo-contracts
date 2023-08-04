// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (access/accesscontrol/accesscontrol.cairo)

#[starknet::contract]
mod AccessControl {
    use openzeppelin::access::accesscontrol::interface;
    use openzeppelin::introspection::interface::ISRC5;
    use openzeppelin::introspection::interface::ISRC5Camel;
    use openzeppelin::introspection::src5::SRC5;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        role_admin: LegacyMap<felt252, felt252>,
        role_members: LegacyMap<(felt252, ContractAddress), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
        RoleAdminChanged: RoleAdminChanged,
    }

    /// Emitted when `account` is granted `role`.
    ///
    /// `sender` is the account that originated the contract call, an admin role
    /// bearer (except if `_grant_role` is called during initialization from the constructor).
    #[derive(Drop, starknet::Event)]
    struct RoleGranted {
        role: felt252,
        account: ContractAddress,
        sender: ContractAddress
    }

    /// Emitted when `account` is revoked `role`.
    ///
    /// `sender` is the account that originated the contract call:
    ///   - If using `revoke_role`, it is the admin role bearer.
    ///   - If using `renounce_role`, it is the role bearer (i.e. `account`).
    #[derive(Drop, starknet::Event)]
    struct RoleRevoked {
        role: felt252,
        account: ContractAddress,
        sender: ContractAddress
    }

    /// Emitted when `new_admin_role` is set as `role`'s admin role, replacing `previous_admin_role`
    ///
    /// `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
    /// {RoleAdminChanged} not being emitted signaling this.
    #[derive(Drop, starknet::Event)]
    struct RoleAdminChanged {
        role: felt252,
        previous_admin_role: felt252,
        new_admin_role: felt252
    }

    #[external(v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            let unsafe_state = SRC5::unsafe_new_contract_state();
            SRC5::SRC5Impl::supports_interface(@unsafe_state, interface_id)
        }
    }

    #[external(v0)]
    impl SRC5CamelImpl of ISRC5Camel<ContractState> {
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            let unsafe_state = SRC5::unsafe_new_contract_state();
            SRC5::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
        }
    }

    #[external(v0)]
    impl AccessControlImpl of interface::IAccessControl<ContractState> {
        fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            self.role_members.read((role, account))
        }

        fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
            self.role_admin.read(role)
        }

        fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            let admin = AccessControlImpl::get_role_admin(@self, role);
            self.assert_only_role(admin);
            self._grant_role(role, account);
        }

        fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            let admin = AccessControlImpl::get_role_admin(@self, role);
            self.assert_only_role(admin);
            self._revoke_role(role, account);
        }

        fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            let caller: ContractAddress = get_caller_address();
            assert(caller == account, 'Can only renounce role for self');
            self._revoke_role(role, account);
        }
    }

    #[external(v0)]
    impl AccessControlCamelImpl of interface::IAccessControlCamel<ContractState> {
        fn hasRole(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            AccessControlImpl::has_role(self, role, account)
        }

        fn getRoleAdmin(self: @ContractState, role: felt252) -> felt252 {
            AccessControlImpl::get_role_admin(self, role)
        }

        fn grantRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            AccessControlImpl::grant_role(ref self, role, account);
        }

        fn revokeRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            AccessControlImpl::revoke_role(ref self, role, account);
        }

        fn renounceRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            AccessControlImpl::renounce_role(ref self, role, account);
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState) {
            let mut unsafe_state = SRC5::unsafe_new_contract_state();
            SRC5::InternalImpl::register_interface(ref unsafe_state, interface::IACCESSCONTROL_ID);
        }

        fn assert_only_role(self: @ContractState, role: felt252) {
            let caller: ContractAddress = get_caller_address();
            let authorized: bool = AccessControlImpl::has_role(self, role, caller);
            assert(authorized, 'Caller is missing role');
        }

        fn _grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            if !AccessControlImpl::has_role(@self, role, account) {
                let caller: ContractAddress = get_caller_address();
                self.role_members.write((role, account), true);
                self.emit(RoleGranted { role, account, sender: caller });
            }
        }

        fn _revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            if AccessControlImpl::has_role(@self, role, account) {
                let caller: ContractAddress = get_caller_address();
                self.role_members.write((role, account), false);
                self.emit(RoleRevoked { role, account, sender: caller });
            }
        }

        fn _set_role_admin(ref self: ContractState, role: felt252, admin_role: felt252) {
            let previous_admin_role: felt252 = AccessControlImpl::get_role_admin(@self, role);
            self.role_admin.write(role, admin_role);
            self.emit(RoleAdminChanged { role, previous_admin_role, new_admin_role: admin_role });
        }
    }
}
