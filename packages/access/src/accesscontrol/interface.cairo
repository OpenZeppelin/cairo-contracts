// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v1.0.0 (access/src/accesscontrol/interface.cairo)

use starknet::ContractAddress;

pub const IACCESSCONTROL_ID: felt252 =
    0x23700be02858dbe2ac4dc9c9f66d0b6b0ed81ec7f970ca6844500a56ff61751;

#[starknet::interface]
pub trait IAccessControl<TState> {
    fn has_role(self: @TState, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @TState, role: felt252) -> felt252;
    fn grant_role(ref self: TState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TState, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: TState, role: felt252, account: ContractAddress);
}

#[starknet::interface]
pub trait IAccessControlCamel<TState> {
    fn hasRole(self: @TState, role: felt252, account: ContractAddress) -> bool;
    fn getRoleAdmin(self: @TState, role: felt252) -> felt252;
    fn grantRole(ref self: TState, role: felt252, account: ContractAddress);
    fn revokeRole(ref self: TState, role: felt252, account: ContractAddress);
    fn renounceRole(ref self: TState, role: felt252, account: ContractAddress);
}

#[starknet::interface]
pub trait AccessControlABI<TState> {
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

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}
