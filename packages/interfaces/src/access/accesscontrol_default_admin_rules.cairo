// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0
// (interfaces/src/access/extensions/accesscontrol_default_admin_rules.cairo)

use starknet::ContractAddress;
use crate::access::accesscontrol::RoleStatus;

pub const IACCESSCONTROL_DEFAULT_ADMIN_RULES_ID: felt252 =
    0x3509b3083c9586afe5dae781146b0608c3846870510f8d4d21ae38676cc33eb;

#[starknet::interface]
pub trait IAccessControlDefaultAdminRules<TState> {
    /// Returns the address of the current `DEFAULT_ADMIN_ROLE` holder.
    fn default_admin(self: @TState) -> ContractAddress;

    /// Returns a tuple of a `new_admin` and an `accept_schedule`.
    ///
    /// After the `accept_schedule` passes, the `new_admin` will be able to accept the
    /// `default_admin` role by calling `accept_default_admin_transfer`, completing the role
    /// transfer.
    ///
    /// A zero value only in `accept_schedule` indicates no pending admin transfer.
    ///
    /// NOTE: A zero address `new_admin` means that `default_admin` is being renounced.
    fn pending_default_admin(self: @TState) -> (ContractAddress, u64);

    /// Returns the delay required to schedule the acceptance of a `default_admin` transfer started.
    ///
    /// This delay will be added to the current timestamp when calling
    /// `begin_default_admin_transfer` to set the acceptance schedule.
    ///
    /// NOTE: If a delay change has been scheduled, it will take effect as soon as the schedule
    /// passes, making this function return the new delay.
    ///
    /// See `change_default_admin_delay`.
    fn default_admin_delay(self: @TState) -> u64;

    /// Returns a tuple of `new_delay` and an `effect_schedule`.
    ///
    /// After the `effect_schedule` passes, the `new_delay` will get into effect immediately for
    /// every new `default_admin` transfer started with `begin_default_admin_transfer`.
    ///
    /// A zero value only in `effect_schedule` indicates no pending delay change.
    ///
    /// NOTE: A zero value only for `new_delay` means that the next `default_admin_delay`
    /// will be zero after the effect schedule.
    fn pending_default_admin_delay(self: @TState) -> (u64, u64);

    /// Starts a `default_admin` transfer by setting a `pending_default_admin` scheduled for
    /// acceptance after the current timestamp plus a `default_admin_delay`.
    ///
    /// Requirements:
    ///
    /// - Only can be called by the current `default_admin`.
    ///
    /// Emits a `DefaultAdminRoleChangeStarted` event.
    fn begin_default_admin_transfer(ref self: TState, new_admin: ContractAddress);

    /// Cancels a `default_admin` transfer previously started with `begin_default_admin_transfer`.
    ///
    /// A `pending_default_admin` not yet accepted can also be canceled with this function.
    ///
    /// Requirements:
    ///
    /// - Only can be called by the current `default_admin`.
    ///
    /// May emit a `DefaultAdminTransferCanceled` event.
    fn cancel_default_admin_transfer(ref self: TState);

    /// Completes a `default_admin` transfer previously started with `begin_default_admin_transfer`.
    ///
    /// After calling the function:
    ///
    /// - `DEFAULT_ADMIN_ROLE` must be granted to the caller.
    /// - `DEFAULT_ADMIN_ROLE` must be revoked from the previous holder.
    /// - `pending_default_admin` must be reset to zero value.
    ///
    /// Requirements:
    ///
    /// - Only can be called by the `pending_default_admin`'s `new_admin`.
    /// - The `pending_default_admin`'s `accept_schedule` should've passed.
    fn accept_default_admin_transfer(ref self: TState);

    /// Initiates a `default_admin_delay` update by setting a `pending_default_admin_delay`
    /// scheduled to take effect after the current timestamp plus a `default_admin_delay`.
    ///
    /// This function guarantees that any call to `begin_default_admin_transfer` done between the
    /// timestamp this method is called at and the `pending_default_admin_delay` effect schedule
    /// will use the current `default_admin_delay` set before calling.
    ///
    /// The `pending_default_admin_delay`'s effect schedule is defined in a way that waiting until
    /// the schedule and then calling `begin_default_admin_transfer` with the new delay will take at
    /// least the same as another `default_admin` complete transfer (including acceptance).
    ///
    /// The schedule is designed for two scenarios:
    ///
    /// - When the delay is changed for a larger one the schedule is `block.timestamp + new delay`
    /// capped by `default_admin_delay_increase_wait`.
    /// - When the delay is changed for a shorter one, the schedule is `block.timestamp + (current
    /// delay - new delay)`.
    ///
    /// A `pending_default_admin_delay` that never got into effect will be canceled in favor of a
    /// new scheduled change.
    ///
    /// Requirements:
    ///
    /// - Only can be called by the current `default_admin`.
    ///
    /// Emits a `DefaultAdminDelayChangeScheduled` event and may emit a
    /// `DefaultAdminDelayChangeCanceled` event.
    fn change_default_admin_delay(ref self: TState, new_delay: u64);

    /// Cancels a scheduled `default_admin_delay` change.
    ///
    /// Requirements:
    ///
    /// - Only can be called by the current `default_admin`.
    ///
    /// May emit a `DefaultAdminDelayChangeCanceled` event.
    fn rollback_default_admin_delay(ref self: TState);

    /// Maximum time in seconds for an increase to `default_admin_delay` (that is scheduled
    /// using `change_default_admin_delay`) to take effect.
    ///
    /// IMPORTANT:
    ///
    /// Make sure to add a reasonable amount of time while setting this value,
    /// otherwise, there's a risk of setting a high new delay that goes into effect almost
    /// immediately without the possibility of human intervention in the case of an input error
    /// (eg. set milliseconds instead of seconds).
    ///
    /// Consider carefully the value set for `maximum_default_admin_transfer_delay` too, since
    /// it will affect how fast you can recover from an accidental delay increase.
    fn default_admin_delay_increase_wait(self: @TState) -> u64;

    /// Maximum time in seconds for a `default_admin` transfer delay.
    ///
    /// IMPORTANT:
    ///
    /// If this value is set too high, you might be unable to recover
    /// from an accidental delay increase for an extended period. Too low, and it unnecessarily
    /// restricts how much security delay you can impose for `default_admin` transfers. As a best
    /// practice, consider setting it in the 30-60 day range for a good balance between security and
    /// recoverability.
    fn maximum_default_admin_transfer_delay(self: @TState) -> u64;
}

#[starknet::interface]
pub trait AccessControlDefaultAdminRulesABI<TState> {
    // IAccessControlDefaultAdminRules
    fn default_admin(self: @TState) -> ContractAddress;
    fn pending_default_admin(self: @TState) -> (ContractAddress, u64);
    fn default_admin_delay(self: @TState) -> u64;
    fn pending_default_admin_delay(self: @TState) -> (u64, u64);
    fn begin_default_admin_transfer(ref self: TState, new_admin: ContractAddress);
    fn cancel_default_admin_transfer(ref self: TState);
    fn accept_default_admin_transfer(ref self: TState);
    fn change_default_admin_delay(ref self: TState, new_delay: u64);
    fn rollback_default_admin_delay(ref self: TState);
    fn default_admin_delay_increase_wait(self: @TState) -> u64;

    // IAccessControl
    fn has_role(self: @TState, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @TState, role: felt252) -> felt252;
    fn grant_role(ref self: TState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TState, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: TState, role: felt252, account: ContractAddress);

    // IAccessControlCamel
    fn hasRole(self: @TState, role: felt252, account: ContractAddress) -> bool;
    fn getRoleAdmin(self: @TState, role: felt252) -> felt252;
    fn grantRole(ref self: TState, role: felt252, account: ContractAddress);
    fn revokeRole(ref self: TState, role: felt252, account: ContractAddress);
    fn renounceRole(ref self: TState, role: felt252, account: ContractAddress);

    // IAccessControlWithDelay
    fn get_role_status(self: @TState, role: felt252, account: ContractAddress) -> RoleStatus;
    fn grant_role_with_delay(ref self: TState, role: felt252, account: ContractAddress, delay: u64);

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}
