// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v1.0.0 (access/src/accesscontrol/accesscontrol.cairo)

/// # AccessControl Component
///
/// The AccessControl component enables role-based access control mechanisms. This is a lightweight
/// implementation that doesn't support on-chain enumeration of role members, though role membership
/// can be tracked off-chain through contract events.
///
/// Roles can be granted and revoked dynamically via `grant_role` and `revoke_role`. Each role
/// has an associated admin role that controls who can grant and revoke it. By default, all roles
/// use `DEFAULT_ADMIN_ROLE` as their admin role.
/// Accounts can also renounce roles they have been granted by using `renounce_role`.
///
/// More complex role hierarchies can be created using `set_role_admin`.
///
/// WARNING: The `DEFAULT_ADMIN_ROLE` is its own admin, meaning it can grant and revoke itself.
/// Extra precautions should be taken to secure accounts with this role.
#[starknet::component]
pub mod AccessControlComponent {
    use crate::accesscontrol::interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    pub struct Storage {
        pub AccessControl_role_admin: Map<felt252, felt252>,
        pub AccessControl_role_member: Map<(felt252, ContractAddress), bool>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
        RoleAdminChanged: RoleAdminChanged,
    }

    /// Emitted when `account` is granted `role`.
    ///
    /// `sender` is the account that originated the contract call, an account with the admin role
    /// or the deployer address if `grant_role` is called from the constructor.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct RoleGranted {
        pub role: felt252,
        pub account: ContractAddress,
        pub sender: ContractAddress,
    }

    /// Emitted when `role` is revoked for `account`.
    ///
    /// `sender` is the account that originated the contract call:
    ///   - If using `revoke_role`, it is the admin role bearer.
    ///   - If using `renounce_role`, it is the role bearer (i.e. `account`).
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct RoleRevoked {
        pub role: felt252,
        pub account: ContractAddress,
        pub sender: ContractAddress,
    }

    /// Emitted when `new_admin_role` is set as `role`'s admin role, replacing `previous_admin_role`
    ///
    /// `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
    /// `RoleAdminChanged` not being emitted signaling this.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct RoleAdminChanged {
        pub role: felt252,
        pub previous_admin_role: felt252,
        pub new_admin_role: felt252,
    }

    pub mod Errors {
        pub const INVALID_CALLER: felt252 = 'Can only renounce role for self';
        pub const MISSING_ROLE: felt252 = 'Caller is missing role';
    }

    #[embeddable_as(AccessControlImpl)]
    impl AccessControl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IAccessControl<ComponentState<TContractState>> {
        /// Returns whether `account` has been granted `role`.
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            self.AccessControl_role_member.read((role, account))
        }

        /// Returns the admin role that controls `role`.
        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.AccessControl_role_admin.read(role)
        }

        /// Grants `role` to `account`.
        ///
        /// If `account` has not been already granted `role`, emits a `RoleGranted` event.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            let admin = Self::get_role_admin(@self, role);
            self.assert_only_role(admin);
            self._grant_role(role, account);
        }

        /// Revokes `role` from `account`.
        ///
        /// If `account` has been granted `role`, emits a `RoleRevoked` event.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            let admin = Self::get_role_admin(@self, role);
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
        /// - The caller must be `account`.
        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            let caller = get_caller_address();
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
        +Drop<TContractState>,
    > of interface::IAccessControlCamel<ComponentState<TContractState>> {
        fn hasRole(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            AccessControl::has_role(self, role, account)
        }

        fn getRoleAdmin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            AccessControl::get_role_admin(self, role)
        }

        fn grantRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControl::grant_role(ref self, role, account);
        }

        fn revokeRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControl::revoke_role(ref self, role, account);
        }

        fn renounceRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControl::renounce_role(ref self, role, account);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering the IAccessControl interface ID.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IACCESSCONTROL_ID);
        }

        /// Validates that the caller has the given role. Otherwise it panics.
        fn assert_only_role(self: @ComponentState<TContractState>, role: felt252) {
            let caller: ContractAddress = get_caller_address();
            let authorized = AccessControl::has_role(self, role, caller);
            assert(authorized, Errors::MISSING_ROLE);
        }

        /// Sets `admin_role` as `role`'s admin role.
        ///
        /// Internal function without access restriction.
        ///
        /// Emits a `RoleAdminChanged` event.
        fn set_role_admin(
            ref self: ComponentState<TContractState>, role: felt252, admin_role: felt252,
        ) {
            let previous_admin_role: felt252 = AccessControl::get_role_admin(@self, role);
            self.AccessControl_role_admin.write(role, admin_role);
            self.emit(RoleAdminChanged { role, previous_admin_role, new_admin_role: admin_role });
        }

        /// Attempts to grant `role` to `account`.
        ///
        /// Internal function without access restriction.
        ///
        /// May emit a `RoleGranted` event.
        fn _grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            if !AccessControl::has_role(@self, role, account) {
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
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            if AccessControl::has_role(@self, role, account) {
                let caller: ContractAddress = get_caller_address();
                self.AccessControl_role_member.write((role, account), false);
                self.emit(RoleRevoked { role, account, sender: caller });
            }
        }
    }

    #[embeddable_as(AccessControlMixinImpl)]
    impl AccessControlMixin<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::AccessControlABI<ComponentState<TContractState>> {
        // IAccessControl
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            AccessControl::has_role(self, role, account)
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            AccessControl::get_role_admin(self, role)
        }

        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControl::grant_role(ref self, role, account);
        }

        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControl::revoke_role(ref self, role, account);
        }

        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControl::renounce_role(ref self, role, account);
        }

        // IAccessControlCamel
        fn hasRole(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            AccessControlCamel::hasRole(self, role, account)
        }

        fn getRoleAdmin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            AccessControlCamel::getRoleAdmin(self, role)
        }

        fn grantRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControlCamel::grantRole(ref self, role, account);
        }

        fn revokeRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControlCamel::revokeRole(ref self, role, account);
        }

        fn renounceRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            AccessControlCamel::renounceRole(ref self, role, account);
        }

        // ISRC5
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252,
        ) -> bool {
            let src5 = get_dep_component!(self, SRC5);
            src5.supports_interface(interface_id)
        }
    }
}
