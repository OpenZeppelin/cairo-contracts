// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.2
// (access/src/accesscontrol/extensions/accesscontrol_default_admin_rules.cairo)

/// # AccessControlDefaultAdminRules Component
///
/// Extension of AccessControl that allows specifying special rules to manage
/// the `DEFAULT_ADMIN_ROLE` holder, which is a sensitive role with special permissions
/// over other roles that may potentially have privileged rights in the system.
///
/// If a specific role doesn't have an admin role assigned, the holder of the
/// `DEFAULT_ADMIN_ROLE` will have the ability to grant it and revoke it.
///
/// This contract implements the following risk mitigations on top of {AccessControl}:
///
/// - Only one account holds the `DEFAULT_ADMIN_ROLE` since deployment until it's potentially
/// renounced.
/// - Enforces a 2-step process to transfer the `DEFAULT_ADMIN_ROLE` to another account.
/// - Enforces a configurable delay between the two steps, with the ability to cancel before the
/// transfer is accepted.
/// - The delay can be changed by scheduling, see `change_default_admin_delay`.
/// - It is not possible to use another role to manage the `DEFAULT_ADMIN_ROLE`.
#[starknet::component]
pub mod AccessControlDefaultAdminRulesComponent {
    use core::num::traits::Zero;
    use core::panic_with_const_felt252;
    use openzeppelin_interfaces::accesscontrol::RoleStatus;
    use openzeppelin_interfaces::{
        accesscontrol as interface,
        accesscontrol_default_admin_rules as default_admin_rules_interface,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalImpl as SRC5InternalImpl, SRC5Impl,
    };
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::accesscontrol::AccessControlComponent::{
        RoleAdminChanged, RoleGranted, RoleGrantedWithDelay, RoleRevoked,
    };
    use crate::accesscontrol::account_role_info::AccountRoleInfo;
    use crate::accesscontrol::extensions::pending_delay::PendingDelay;

    pub const DEFAULT_ADMIN_ROLE: felt252 = 0;

    #[storage]
    pub struct Storage {
        pub AccessControl_role_admin: Map<felt252, felt252>,
        pub AccessControl_role_member: Map<(felt252, ContractAddress), AccountRoleInfo>,
        pub AccessControl_pending_default_admin: ContractAddress,
        pub AccessControl_pending_default_admin_schedule: u64, // 0 if not scheduled
        pub AccessControl_current_delay: u64,
        pub AccessControl_current_default_admin: ContractAddress,
        pub AccessControl_pending_delay: PendingDelay,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        RoleGranted: RoleGranted,
        RoleGrantedWithDelay: RoleGrantedWithDelay,
        RoleRevoked: RoleRevoked,
        RoleAdminChanged: RoleAdminChanged,
        DefaultAdminTransferScheduled: DefaultAdminTransferScheduled,
        DefaultAdminTransferCanceled: DefaultAdminTransferCanceled,
        DefaultAdminDelayChangeScheduled: DefaultAdminDelayChangeScheduled,
        DefaultAdminDelayChangeCanceled: DefaultAdminDelayChangeCanceled,
    }

    /// Emitted when a `default_admin` transfer is started.
    ///
    /// Sets `new_admin` as the next address to become the `default_admin` by calling
    /// `accept_default_admin_transfer` only after accept_schedule` passes.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DefaultAdminTransferScheduled {
        #[key]
        pub new_admin: ContractAddress,
        pub accept_schedule: u64,
    }

    /// Emitted when a `pending_default_admin` is reset if it was never
    /// accepted, regardless of its schedule.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DefaultAdminTransferCanceled {}

    /// Emitted when a `default_admin_delay` change is started.
    ///
    /// Sets `new_delay` as the next delay to be applied between default admins transfers
    /// after `effect_schedule` has passed.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DefaultAdminDelayChangeScheduled {
        pub new_delay: u64,
        pub effect_schedule: u64,
    }

    /// Emitted when a `pending_default_admin_delay` is reset if its schedule didn't pass.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DefaultAdminDelayChangeCanceled {}

    pub mod Errors {
        /// AccessControl errors
        pub const INVALID_CALLER: felt252 = 'Can only renounce role for self';
        pub const MISSING_ROLE: felt252 = 'Caller is missing role';
        pub const INVALID_DELAY: felt252 = 'Delay must be greater than 0';
        pub const ALREADY_EFFECTIVE: felt252 = 'Role is already effective';

        /// DefaultAdminRules extension errors
        pub const INVALID_DEFAULT_ADMIN: felt252 = 'Invalid default admin';
        pub const ONLY_NEW_DEFAULT_ADMIN: felt252 = 'Only new default admin allowed';
        pub const ENFORCED_DEFAULT_ADMIN_RULES: felt252 = 'Default admin rules enforced';
        pub const ENFORCED_DEFAULT_ADMIN_DELAY: felt252 = 'Default admin delay enforced';
    }

    /// Constants expected to be defined at the contract level used to configure the component
    /// behavior.
    ///
    /// - `DEFAULT_ADMIN_DELAY_INCREASE_WAIT`: Returns the maximum number of seconds to wait for a
    /// delay increase.
    pub trait ImmutableConfig {
        const DEFAULT_ADMIN_DELAY_INCREASE_WAIT: u64;
    }

    #[embeddable_as(AccessControlDefaultAdminRulesImpl)]
    impl AccessControlDefaultAdminRules<
        TContractState,
        +HasComponent<TContractState>,
        impl Immutable: ImmutableConfig,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of default_admin_rules_interface::IAccessControlDefaultAdminRules<
        ComponentState<TContractState>,
    > {
        /// Returns the address of the current `DEFAULT_ADMIN_ROLE` holder.
        fn default_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.AccessControl_current_default_admin.read()
        }

        /// Returns a tuple of a `new_admin` and an `accept_schedule`.
        ///
        /// After the `accept_schedule` passes, the `new_admin` will be able to accept the
        /// `default_admin` role by calling `accept_default_admin_transfer`, completing the role
        /// transfer.
        ///
        /// A zero value only in `accept_schedule` indicates no pending admin transfer.
        ///
        /// NOTE: A zero address `new_admin` means that `default_admin` is being renounced.
        fn pending_default_admin(self: @ComponentState<TContractState>) -> (ContractAddress, u64) {
            let pending_default_admin = self.AccessControl_pending_default_admin.read();
            let pending_default_admin_schedule = self
                .AccessControl_pending_default_admin_schedule
                .read();
            (pending_default_admin, pending_default_admin_schedule)
        }

        /// Returns the delay required to schedule the acceptance of a `default_admin` transfer
        /// started.
        ///
        /// This delay will be added to the current timestamp when calling
        /// `begin_default_admin_transfer` to set the acceptance schedule.
        ///
        /// NOTE: If a delay change has been scheduled, it will take effect as soon as the schedule
        /// passes, making this function return the new delay.
        ///
        /// See `change_default_admin_delay`.
        fn default_admin_delay(self: @ComponentState<TContractState>) -> u64 {
            let pending_delay = self.AccessControl_pending_delay.read();
            let schedule = pending_delay.schedule;

            if is_schedule_set(schedule) && has_schedule_passed(schedule) {
                pending_delay.delay
            } else {
                self.AccessControl_current_delay.read()
            }
        }

        /// Returns a tuple of `new_delay` and an `effect_schedule`.
        ///
        /// After the `effect_schedule` passes, the `new_delay` will get into effect immediately for
        /// every new `default_admin` transfer started with `begin_default_admin_transfer`.
        ///
        /// A zero value only in `effect_schedule` indicates no pending delay change.
        ///
        /// NOTE: A zero value only for `new_delay` means that the next `default_admin_delay`
        /// will be zero after the effect schedule.
        fn pending_default_admin_delay(self: @ComponentState<TContractState>) -> (u64, u64) {
            let pending_delay = self.AccessControl_pending_delay.read();
            let schedule = pending_delay.schedule;

            if is_schedule_set(schedule) && !has_schedule_passed(schedule) {
                let delay = pending_delay.delay;
                (delay, schedule)
            } else {
                (0, 0)
            }
        }

        /// Starts a `default_admin` transfer by setting a `pending_default_admin` scheduled for
        /// acceptance after the current timestamp plus a `default_admin_delay`.
        ///
        /// Requirements:
        ///
        /// - Only can be called by the current `default_admin`.
        ///
        /// Emits a `DefaultAdminRoleChangeStarted` event.
        fn begin_default_admin_transfer(
            ref self: ComponentState<TContractState>, new_admin: ContractAddress,
        ) {
            self.assert_only_role(DEFAULT_ADMIN_ROLE);

            let new_schedule = starknet::get_block_timestamp() + Self::default_admin_delay(@self);
            self.set_pending_default_admin(new_admin, new_schedule);
            self.emit(DefaultAdminTransferScheduled { new_admin, accept_schedule: new_schedule });
        }

        /// Cancels a `default_admin` transfer previously started with
        /// `begin_default_admin_transfer`.
        ///
        /// A `pending_default_admin` not yet accepted can also be canceled with this function.
        ///
        /// Requirements:
        ///
        /// - Only can be called by the current `default_admin`.
        ///
        /// May emit a `DefaultAdminTransferCanceled` event.
        fn cancel_default_admin_transfer(ref self: ComponentState<TContractState>) {
            self.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.set_pending_default_admin(Zero::zero(), 0);
        }

        /// Completes a `default_admin` transfer previously started with
        /// `begin_default_admin_transfer`.
        ///
        /// After calling the function:
        ///
        /// - `DEFAULT_ADMIN_ROLE` must be granted to the caller.
        /// - `DEFAULT_ADMIN_ROLE` must be revoked from the previous holder.
        /// - `pending_default_admin` must be reset to zero values.
        ///
        /// Requirements:
        ///
        /// - Only can be called by the `pending_default_admin`'s `new_admin`.
        /// - The `pending_default_admin`'s `accept_schedule` should've passed.
        fn accept_default_admin_transfer(ref self: ComponentState<TContractState>) {
            let (new_default_admin, schedule) = Self::pending_default_admin(@self);
            // Enforce that the caller is the `new_default_admin`
            assert(
                new_default_admin == starknet::get_caller_address(), Errors::ONLY_NEW_DEFAULT_ADMIN,
            );

            if !is_schedule_set(schedule) || !has_schedule_passed(schedule) {
                panic_with_const_felt252::<Errors::ENFORCED_DEFAULT_ADMIN_DELAY>();
            }

            self._revoke_role(DEFAULT_ADMIN_ROLE, Self::default_admin(@self));
            self._grant_role(DEFAULT_ADMIN_ROLE, new_default_admin);

            self.AccessControl_pending_default_admin.write(Zero::zero());
            self.AccessControl_pending_default_admin_schedule.write(0);
        }

        /// Initiates a `default_admin_delay` update by setting a `pending_default_admin_delay`
        /// scheduled for getting into effect after the current timestamp plus a
        /// `default_admin_delay`.
        ///
        /// This function guarantees that any call to `begin_default_admin_transfer` done between
        /// the timestamp this method is called at and the `pending_default_admin_delay` effect
        /// schedule will use the current `default_admin_delay`
        /// set before calling.
        ///
        /// The `pending_default_admin_delay`'s effect schedule is defined in a way that waiting
        /// until the schedule and then calling `begin_default_admin_transfer` with the new delay
        /// will take at least the same as another `default_admin`
        /// complete transfer (including acceptance).
        ///
        /// The schedule is designed for two scenarios:
        ///
        /// - When the delay is changed for a larger one the schedule is `block.timestamp +
        /// new delay` capped by `default_admin_delay_increase_wait`.
        /// - When the delay is changed for a shorter one, the schedule is `block.timestamp +
        /// (current delay - new delay)`.
        ///
        /// A `pending_default_admin_delay` that never got into effect will be canceled in favor of
        /// a new scheduled change.
        ///
        /// Requirements:
        ///
        /// - Only can be called by the current `default_admin`.
        ///
        /// Emits a `DefaultAdminDelayChangeScheduled` event and may emit a
        /// `DefaultAdminDelayChangeCanceled` event.
        fn change_default_admin_delay(ref self: ComponentState<TContractState>, new_delay: u64) {
            self.assert_only_role(DEFAULT_ADMIN_ROLE);

            let new_schedule = starknet::get_block_timestamp() + self.delay_change_wait(new_delay);
            self.set_pending_delay(new_delay, new_schedule);
            self
                .emit(
                    DefaultAdminDelayChangeScheduled { new_delay, effect_schedule: new_schedule },
                );
        }

        /// Cancels a scheduled `default_admin_delay` change.
        ///
        /// Requirements:
        ///
        /// - Only can be called by the current `default_admin`.
        ///
        /// May emit a `DefaultAdminDelayChangeCanceled` event.
        fn rollback_default_admin_delay(ref self: ComponentState<TContractState>) {
            self.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.set_pending_delay(0, 0);
        }

        /// Maximum time in seconds for an increase to `default_admin_delay` (that is scheduled
        /// using `change_default_admin_delay`)
        /// to take effect. Defaults to 5 days.
        ///
        /// When the `default_admin_delay` is scheduled to be increased, it goes into effect after
        /// the new delay has passed with the purpose of giving enough time for reverting any
        /// accidental change (i.e. using milliseconds instead of seconds)
        /// that may lock the contract. However, to avoid excessive schedules, the wait is capped by
        /// this function and it can be overridden for a custom `default_admin_delay` increase
        /// scheduling.
        ///
        /// IMPORTANT: Make sure to add a reasonable amount of time while overriding this value,
        /// otherwise, there's a risk of setting a high new delay that goes into effect almost
        /// immediately without the possibility of human intervention in the case of an input error
        /// (eg. set milliseconds instead of seconds).
        fn default_admin_delay_increase_wait(self: @ComponentState<TContractState>) -> u64 {
            Immutable::DEFAULT_ADMIN_DELAY_INCREASE_WAIT
        }
    }

    #[embeddable_as(AccessControlImpl)]
    impl AccessControl<
        TContractState,
        +HasComponent<TContractState>,
        +ImmutableConfig,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IAccessControl<ComponentState<TContractState>> {
        /// Returns whether `account` can act as `role`.
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            self.is_role_effective(role, account)
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
        /// - `role` must not be the `DEFAULT_ADMIN_ROLE`.
        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            assert(role != DEFAULT_ADMIN_ROLE, Errors::ENFORCED_DEFAULT_ADMIN_RULES);

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
        /// - `role` must not be the `DEFAULT_ADMIN_ROLE`.
        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            assert(role != DEFAULT_ADMIN_ROLE, Errors::ENFORCED_DEFAULT_ADMIN_RULES);

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
        /// For the `DEFAULT_ADMIN_ROLE`, it only allows renouncing in two steps by first calling
        /// `begin_default_admin_transfer` to the zero address, so it's required that the
        /// `pending_default_admin_schedule` has also passed when calling this function.
        ///
        /// After its execution, it will not be possible to call
        /// `assert_only_role(DEFAULT_ADMIN_ROLE)`-protected functions.
        ///
        /// NOTE: Renouncing `DEFAULT_ADMIN_ROLE` will leave the contract without a `default_admin`,
        /// thereby disabling any functionality that is only available for it, and the possibility
        /// of reassigning a non-administrated role.
        ///
        /// Requirements:
        ///
        /// - The caller must be `account`.
        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            if role == DEFAULT_ADMIN_ROLE
                && account == AccessControlDefaultAdminRules::default_admin(@self) {
                let (new_default_admin, schedule) =
                    AccessControlDefaultAdminRules::pending_default_admin(
                    @self,
                );
                if new_default_admin.is_non_zero()
                    || !is_schedule_set(schedule)
                    || !has_schedule_passed(schedule) {
                    panic_with_const_felt252::<Errors::ENFORCED_DEFAULT_ADMIN_DELAY>();
                }
                self.AccessControl_pending_default_admin_schedule.write(0);
            }

            let caller = starknet::get_caller_address();
            assert(caller == account, Errors::INVALID_CALLER);
            self._revoke_role(role, account);
        }
    }

    /// Adds camelCase support for `IAccessControl`.
    #[embeddable_as(AccessControlCamelImpl)]
    impl AccessControlCamel<
        TContractState,
        +HasComponent<TContractState>,
        +ImmutableConfig,
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

    #[embeddable_as(AccessControlWithDelayImpl)]
    impl AccessControlWithDelay<
        TContractState,
        +HasComponent<TContractState>,
        +ImmutableConfig,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IAccessControlWithDelay<ComponentState<TContractState>> {
        /// Returns the account's status for the given role.
        ///
        /// The possible statuses are:
        ///
        /// - `NotGranted`: the role has not been granted to the account.
        /// - `Delayed`: The role has been granted to the account but is not yet active due to a
        /// time delay.
        /// - `Effective`: the role has been granted to the account and is currently active.
        fn get_role_status(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> RoleStatus {
            self.resolve_role_status(role, account)
        }

        /// Attempts to grant `role` to `account` with the specified activation delay.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        /// - delay must be greater than 0.
        /// - the `role` must not be already effective for `account`.
        ///
        /// May emit a `RoleGrantedWithDelay` event.
        fn grant_role_with_delay(
            ref self: ComponentState<TContractState>,
            role: felt252,
            account: ContractAddress,
            delay: u64,
        ) {
            let admin = AccessControl::get_role_admin(@self, role);
            self.assert_only_role(admin);
            self._grant_role_with_delay(role, account, delay);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +ImmutableConfig,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering the IAccessControl interface ID and
        /// setting the initial delay and default admin.
        ///
        /// Requirements:
        ///
        /// - initial_default_admin must not be the zero address.
        fn initializer(
            ref self: ComponentState<TContractState>,
            initial_delay: u64,
            initial_default_admin: ContractAddress,
        ) {
            assert(initial_default_admin.is_non_zero(), Errors::INVALID_DEFAULT_ADMIN);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);

            let default_admin_rules_interface_id =
                default_admin_rules_interface::IACCESSCONTROL_DEFAULT_ADMIN_RULES_ID;
            src5_component.register_interface(interface::IACCESSCONTROL_ID);
            src5_component.register_interface(default_admin_rules_interface_id);

            self.AccessControl_current_delay.write(initial_delay);
            self._grant_role(DEFAULT_ADMIN_ROLE, initial_default_admin);
        }

        /// Validates that the caller can act as the given role. Otherwise it panics.
        fn assert_only_role(self: @ComponentState<TContractState>, role: felt252) {
            let caller = starknet::get_caller_address();
            let authorized = self.is_role_effective(role, caller);
            assert(authorized, Errors::MISSING_ROLE);
        }

        /// Returns whether the account can act as the given role.
        ///
        /// The account can act as the role if it is active and the `effective_from` time is before
        /// or equal to the current time.
        ///
        /// NOTE: If the `effective_from` timepoint is 0, the role is effective immediately.
        /// This is backwards compatible with implementations that didn't use delays but
        /// a single boolean flag.
        fn is_role_effective(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            match self.resolve_role_status(role, account) {
                RoleStatus::Effective => true,
                RoleStatus::Delayed(_) => false,
                RoleStatus::NotGranted => false,
            }
        }

        /// Returns the account's status for the given role.
        ///
        /// The possible statuses are:
        ///
        /// - `NotGranted`: the role has not been granted to the account.
        /// - `Delayed`: The role has been granted to the account but is not yet active due to a
        /// time delay.
        /// - `Effective`: the role has been granted to the account and is currently active.
        fn resolve_role_status(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> RoleStatus {
            let AccountRoleInfo {
                is_granted, effective_from,
            } = self.AccessControl_role_member.read((role, account));
            if is_granted {
                if effective_from == 0 {
                    RoleStatus::Effective
                } else {
                    let now = starknet::get_block_timestamp();
                    if effective_from <= now {
                        RoleStatus::Effective
                    } else {
                        RoleStatus::Delayed(effective_from)
                    }
                }
            } else {
                RoleStatus::NotGranted
            }
        }

        /// Returns whether the account has the given role granted.
        ///
        /// NOTE: The account may not be able to act as the role yet, if a delay was set and has not
        /// passed yet. Use `is_role_effective` to check if the account can act as the role.
        fn is_role_granted(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            let account_role_info = self.AccessControl_role_member.read((role, account));
            account_role_info.is_granted
        }

        /// Sets `admin_role` as `role`'s admin role.
        ///
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `role` must not be `DEFAULT_ADMIN_ROLE`.
        ///
        /// Emits a `RoleAdminChanged` event.
        fn set_role_admin(
            ref self: ComponentState<TContractState>, role: felt252, admin_role: felt252,
        ) {
            assert(role != DEFAULT_ADMIN_ROLE, Errors::ENFORCED_DEFAULT_ADMIN_RULES);

            let previous_admin_role = AccessControl::get_role_admin(@self, role);
            self.AccessControl_role_admin.write(role, admin_role);
            self.emit(RoleAdminChanged { role, previous_admin_role, new_admin_role: admin_role });
        }

        /// Attempts to grant `role` to `account`. The function does nothing if `role` is already
        /// effective for `account`. If `role` has been granted to `account`, but is not yet active
        /// due to a time delay, the delay is removed and `role` becomes effective immediately.
        ///
        /// Internal function without access restriction.
        ///
        /// For `DEFAULT_ADMIN_ROLE`, it only allows granting if there isn't already a
        /// `default_admin`
        /// or if the role has been previously renounced.
        ///
        /// NOTE: Exposing this function through another mechanism may make the `DEFAULT_ADMIN_ROLE`
        /// assignable again. Make sure to guarantee this is the expected behavior in your
        /// implementation.
        ///
        /// May emit a `RoleGranted` event.
        fn _grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            if role == DEFAULT_ADMIN_ROLE {
                assert(
                    AccessControlDefaultAdminRules::default_admin(@self) == Zero::zero(),
                    Errors::ENFORCED_DEFAULT_ADMIN_RULES,
                );
                self.AccessControl_current_default_admin.write(account);
            }

            match self.resolve_role_status(role, account) {
                RoleStatus::Effective => (),
                RoleStatus::Delayed(_) |
                RoleStatus::NotGranted => {
                    let caller = starknet::get_caller_address();
                    let role_info = AccountRoleInfo { is_granted: true, effective_from: 0 };
                    self.AccessControl_role_member.write((role, account), role_info);
                    self.emit(RoleGranted { role, account, sender: caller });
                },
            };
        }

        /// Attempts to grant `role` to `account` with the specified activation delay.
        ///
        /// The role will become effective after the given delay has passed. If the role is already
        /// active (`Effective`) for the account, the function will panic. If the role has been
        /// granted but is not yet active (being in the `Delayed` state), the existing delay will be
        /// overwritten with the new `delay`.
        ///
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - delay must be greater than 0.
        /// - the `role` must not be already effective for `account`.
        /// - `role` must not be `DEFAULT_ADMIN_ROLE`.
        ///
        /// May emit a `RoleGrantedWithDelay` event.
        fn _grant_role_with_delay(
            ref self: ComponentState<TContractState>,
            role: felt252,
            account: ContractAddress,
            delay: u64,
        ) {
            assert(role != DEFAULT_ADMIN_ROLE, Errors::ENFORCED_DEFAULT_ADMIN_RULES);
            assert(delay > 0, Errors::INVALID_DELAY);

            match self.resolve_role_status(role, account) {
                RoleStatus::Effective => panic_with_const_felt252::<Errors::ALREADY_EFFECTIVE>(),
                RoleStatus::Delayed(_) |
                RoleStatus::NotGranted => {
                    let caller = starknet::get_caller_address();
                    let effective_from = starknet::get_block_timestamp() + delay;
                    let role_info = AccountRoleInfo { is_granted: true, effective_from };
                    self.AccessControl_role_member.write((role, account), role_info);
                    self.emit(RoleGrantedWithDelay { role, account, sender: caller, delay });
                },
            };
        }

        /// Attempts to revoke `role` from `account`.
        ///
        /// Internal function without access restriction.
        ///
        /// May emit a `RoleRevoked` event.
        fn _revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            if role == DEFAULT_ADMIN_ROLE
                && account == AccessControlDefaultAdminRules::default_admin(@self) {
                self.AccessControl_current_default_admin.write(Zero::zero());
            }

            match self.resolve_role_status(role, account) {
                RoleStatus::NotGranted => (),
                RoleStatus::Effective |
                RoleStatus::Delayed(_) => {
                    let caller = starknet::get_caller_address();
                    let role_info = AccountRoleInfo { is_granted: false, effective_from: 0 };
                    self.AccessControl_role_member.write((role, account), role_info);
                    self.emit(RoleRevoked { role, account, sender: caller });
                },
            };
        }

        /// Setter of the tuple for pending admin and its schedule.
        ///
        /// May emit a `DefaultAdminTransferCanceled` event.
        fn set_pending_default_admin(
            ref self: ComponentState<TContractState>, new_admin: ContractAddress, new_schedule: u64,
        ) {
            let (_, old_schedule) = AccessControlDefaultAdminRules::pending_default_admin(@self);

            self.AccessControl_pending_default_admin.write(new_admin);
            self.AccessControl_pending_default_admin_schedule.write(new_schedule);

            // An `old_schedule` from `pending_default_admin()` is only set if it hasn't been
            // accepted
            if is_schedule_set(old_schedule) {
                self.emit(DefaultAdminTransferCanceled {});
            }
        }

        /// Setter of the tuple for pending delay and its schedule.
        ///
        /// May emit a `DefaultAdminDelayChangeCanceled` event.
        fn set_pending_delay(
            ref self: ComponentState<TContractState>, new_delay: u64, new_schedule: u64,
        ) {
            let pending_delay = self.AccessControl_pending_delay.read();
            let old_schedule = pending_delay.schedule;

            if is_schedule_set(old_schedule) {
                if has_schedule_passed(old_schedule) {
                    // Materialize a virtual delay
                    self.AccessControl_current_delay.write(pending_delay.delay);
                } else {
                    // Emit for implicit cancellations when another delay was scheduled
                    self.emit(DefaultAdminDelayChangeCanceled {});
                }
            }

            let new_pending_delay = PendingDelay { delay: new_delay, schedule: new_schedule };
            self.AccessControl_pending_delay.write(new_pending_delay);
        }

        /// Returns the amount of seconds to wait after the `new_delay` will
        /// become the new `default_admin_delay`.
        ///
        /// The value returned guarantees that if the delay is reduced, it will go into effect
        /// after a wait that honors the previously set delay.
        ///
        /// See `default_admin_delay_increase_wait`.
        fn delay_change_wait(self: @ComponentState<TContractState>, new_delay: u64) -> u64 {
            let current_delay = self.AccessControl_current_delay.read();

            // When increasing the delay, we schedule the delay change to occur after a period of
            // "new delay" has passed, up to a maximum given by defaultAdminDelayIncreaseWait, by
            // default 5 days. For example, if increasing from 1 day to 3 days, the new delay will
            // come into effect after 3 days. If increasing from 1 day to 10 days, the new delay
            // will come into effect after 5 days. The 5 day wait period is intended to be able to
            // fix an error like using milliseconds instead of seconds.
            //
            // When decreasing the delay, we wait the difference between "current delay" and "new
            // delay". This guarantees that an admin transfer cannot be made faster than "current
            // delay" at the time the delay change is scheduled.
            // For example, if decreasing from 10 days to 3 days, the new delay will come into
            // effect after 7 days.
            if new_delay > current_delay {
                core::cmp::min(
                    new_delay,
                    AccessControlDefaultAdminRules::default_admin_delay_increase_wait(self),
                )
            } else {
                current_delay - new_delay
            }
        }
    }

    #[embeddable_as(AccessControlMixinImpl)]
    impl AccessControlMixin<
        TContractState,
        +HasComponent<TContractState>,
        +ImmutableConfig,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of default_admin_rules_interface::AccessControlDefaultAdminRulesABI<
        ComponentState<TContractState>,
    > {
        // IAccessControlDefaultAdminRules
        fn default_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            AccessControlDefaultAdminRules::default_admin(self)
        }

        fn pending_default_admin(self: @ComponentState<TContractState>) -> (ContractAddress, u64) {
            AccessControlDefaultAdminRules::pending_default_admin(self)
        }

        fn default_admin_delay(self: @ComponentState<TContractState>) -> u64 {
            AccessControlDefaultAdminRules::default_admin_delay(self)
        }

        fn pending_default_admin_delay(self: @ComponentState<TContractState>) -> (u64, u64) {
            AccessControlDefaultAdminRules::pending_default_admin_delay(self)
        }

        fn begin_default_admin_transfer(
            ref self: ComponentState<TContractState>, new_admin: ContractAddress,
        ) {
            AccessControlDefaultAdminRules::begin_default_admin_transfer(ref self, new_admin);
        }

        fn cancel_default_admin_transfer(ref self: ComponentState<TContractState>) {
            AccessControlDefaultAdminRules::cancel_default_admin_transfer(ref self);
        }

        fn accept_default_admin_transfer(ref self: ComponentState<TContractState>) {
            AccessControlDefaultAdminRules::accept_default_admin_transfer(ref self);
        }

        fn change_default_admin_delay(ref self: ComponentState<TContractState>, new_delay: u64) {
            AccessControlDefaultAdminRules::change_default_admin_delay(ref self, new_delay);
        }

        fn rollback_default_admin_delay(ref self: ComponentState<TContractState>) {
            AccessControlDefaultAdminRules::rollback_default_admin_delay(ref self);
        }

        fn default_admin_delay_increase_wait(self: @ComponentState<TContractState>) -> u64 {
            AccessControlDefaultAdminRules::default_admin_delay_increase_wait(self)
        }

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

        // IAccessControlWithDelay
        fn get_role_status(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> RoleStatus {
            AccessControlWithDelay::get_role_status(self, role, account)
        }

        fn grant_role_with_delay(
            ref self: ComponentState<TContractState>,
            role: felt252,
            account: ContractAddress,
            delay: u64,
        ) {
            AccessControlWithDelay::grant_role_with_delay(ref self, role, account, delay);
        }

        // ISRC5
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252,
        ) -> bool {
            let src5 = get_dep_component!(self, SRC5);
            src5.supports_interface(interface_id)
        }
    }

    //
    // Private helpers
    //

    /// Defines if an `schedule` is considered set. For consistency purposes.
    fn is_schedule_set(schedule: u64) -> bool {
        schedule != 0
    }

    /// Defines if an `schedule` is considered passed. For consistency purposes.
    fn has_schedule_passed(schedule: u64) -> bool {
        let now = starknet::get_block_timestamp();
        now >= schedule
    }
}

/// Implementation of the default ERC20Component ImmutableConfig.
///
/// See
/// https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-107.md#defaultconfig-implementation
///
/// The default delay increase wait is set to `DEFAULT_ADMIN_DELAY_INCREASE_WAIT`.
pub impl DefaultConfig of AccessControlDefaultAdminRulesComponent::ImmutableConfig {
    const DEFAULT_ADMIN_DELAY_INCREASE_WAIT: u64 = 5 * 24 * 60 * 60; // 5 days
}
