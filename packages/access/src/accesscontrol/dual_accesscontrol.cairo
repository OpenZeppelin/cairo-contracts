// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (access/accesscontrol/dual_accesscontrol.cairo)

use openzeppelin_utils::selectors;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::try_selector_with_fallback;
use openzeppelin_utils::unwrap_and_cast::UnwrapAndCast;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

#[derive(Copy, Drop)]
pub struct DualCaseAccessControl {
    pub contract_address: ContractAddress
}

pub trait DualCaseAccessControlTrait {
    fn has_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @DualCaseAccessControl, role: felt252) -> felt252;
    fn grant_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress);
    fn revoke_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress);
    fn renounce_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress);
    fn supports_interface(self: @DualCaseAccessControl, interface_id: felt252) -> bool;
}

impl DualCaseAccessControlImpl of DualCaseAccessControlTrait {
    fn has_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) -> bool {
        let mut args = array![];
        args.append_serde(role);
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selectors::has_role, selectors::hasRole, args.span()
        )
            .unwrap_and_cast()
    }

    fn get_role_admin(self: @DualCaseAccessControl, role: felt252) -> felt252 {
        let mut args = array![];
        args.append_serde(role);

        try_selector_with_fallback(
            *self.contract_address, selectors::get_role_admin, selectors::getRoleAdmin, args.span()
        )
            .unwrap_and_cast()
    }

    fn grant_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let mut args = array![];
        args.append_serde(role);
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selectors::grant_role, selectors::grantRole, args.span()
        )
            .unwrap_syscall();
    }

    fn revoke_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let mut args = array![];
        args.append_serde(role);
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selectors::revoke_role, selectors::revokeRole, args.span()
        )
            .unwrap_syscall();
    }

    fn renounce_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let mut args = array![];
        args.append_serde(role);
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selectors::renounce_role, selectors::renounceRole, args.span()
        )
            .unwrap_syscall();
    }

    fn supports_interface(self: @DualCaseAccessControl, interface_id: felt252) -> bool {
        let mut args = array![];
        args.append_serde(interface_id);

        call_contract_syscall(*self.contract_address, selectors::supports_interface, args.span())
            .unwrap_and_cast()
    }
}
