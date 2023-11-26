// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.0 (access/accesscontrol/accesscontrol.cairo)

/// # AccessControl Component
///
/// The AccessControl component allows contracts to implement role-based access control mechanisms.
/// Roles are referred to by their `felt252` identifier.
#[starknet::component]
mod AccessControlComponent {
    use openzeppelin::access::accesscontrol::interface;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        AccessControl_role_admin: LegacyMap<felt252, felt252>,
        AccessControl_role_member: LegacyMap<(felt252, ContractAddress), bool>,
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

    mod Errors {
        const INVALID_CALLER: felt252 = 'Can only renounce role for self';
        const MISSING_ROLE: felt252 = 'Caller is missing role';
    }

    #[embeddable_as(AccessControlImpl)]
    impl AccessControl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IAccessControl<ComponentState<TContractState>> {
        /// Returns whether `account` has been granted `role`.
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            self.AccessControl_role_member.read((role, account))
        }

        /// Returns the admin role that controls `role`.
        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.AccessControl_role_admin.read(role)
        }

        /// Grants `role` to `account`.
        ///
        /// If `account` had not been already granted `role`, emits a `RoleGranted` event.
        ///
        /// Requirements:
        ///
        /// - the caller must have `role`'s admin role.
        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let admin = self.get_role_admin(role);
            self.assert_only_role(admin);
            self._grant_role(role, account);
        }

        /// Revokes `role` from `account`.
        ///
        /// If `account` had been granted `role`, emits a `RoleRevoked` event.
        ///
        /// Requirements:
        ///
        /// - the caller must have `role`'s admin role.
        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let admin = self.get_role_admin(role);
            self.assert_only_role(admin);
            self._revoke_role(role, account);
        }

        /// Revokes `role` from the calling account.
        ///
        /// Roles are often managed via `grant_role` and `revoke_role`: this function's
        /// purpose is to provide a mechanism for accounts to lose their privileges
        /// if they are compromised (such as when a trusted device is misplaced).
        ///
        /// If the calling account had been revoked `role`, emits a `RoleRevoked`
        /// event.
        ///
        /// Requirements:
        ///
        /// - the caller must be `account`.
        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let caller: ContractAddress = get_caller_address();
            assert(caller == account, Errors::INVALID_CALLER);
            self._revoke_role(role, account);
        }
    }

    /// Adds camelCase support for `IAccessControl`.
    #[embeddable_as(AccessControlCamelImpl)]
    impl AccessControlCamel<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IAccessControlCamel<ComponentState<TContractState>> {
        fn hasRole(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            self.has_role(role, account)
        }

        fn getRoleAdmin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.get_role_admin(role)
        }

        fn grantRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.grant_role(role, account);
        }

        fn revokeRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.revoke_role(role, account);
        }

        fn renounceRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.renounce_role(role, account);
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering the IAccessControl interface Id.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IACCESSCONTROL_ID);
        }

        /// Validates that the caller has the given role. Otherwise it panics.
        fn assert_only_role(self: @ComponentState<TContractState>, role: felt252) {
            let caller: ContractAddress = get_caller_address();
            let authorized: bool = self.has_role(role, caller);
            assert(authorized, Errors::MISSING_ROLE);
        }

        /// Attempts to grant `role` to `account`.
        ///
        /// Internal function without access restriction.
        ///
        /// May emit a `RoleGranted` event.
        fn _grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            if !self.has_role(role, account) {
                let caller: ContractAddress = get_caller_address();
                self.AccessControl_role_member.write((role, account), true);
                self.emit(RoleGranted { role, account, sender: caller });
            }
        }

        /// Attempts to revoke `role` from `account`.
        ///
        /// Internal function without access restriction.
        ///
        /// May emit a `RoleRevoked` event.
        fn _revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            if self.has_role(role, account) {
                let caller: ContractAddress = get_caller_address();
                self.AccessControl_role_member.write((role, account), false);
                self.emit(RoleRevoked { role, account, sender: caller });
            }
        }

        /// Sets `admin_role` as `role`'s admin role.
        ///
        /// Emits a `RoleAdminChanged` event.
        fn _set_role_admin(
            ref self: ComponentState<TContractState>, role: felt252, admin_role: felt252
        ) {
            let previous_admin_role: felt252 = self.get_role_admin(role);
            self.AccessControl_role_admin.write(role, admin_role);
            self.emit(RoleAdminChanged { role, previous_admin_role, new_admin_role: admin_role });
        }
    }
}
