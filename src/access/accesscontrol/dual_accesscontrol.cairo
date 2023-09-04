// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (access/accesscontrol/dual_accesscontrol.cairo)

use array::ArrayTrait;

use openzeppelin::utils::Felt252TryIntoBool;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;

#[derive(Copy, Drop)]
struct DualCaseAccessControl {
    contract_address: ContractAddress
}

trait DualCaseAccessControlTrait {
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
            *self.contract_address, selector!("has_role"), selector!("hasRole"), args.span()
        )
            .unwrap_and_cast()
    }

    fn get_role_admin(self: @DualCaseAccessControl, role: felt252) -> felt252 {
        let mut args = array![];
        args.append_serde(role);

        try_selector_with_fallback(
            *self.contract_address,
            selector!("get_role_admin"),
            selector!("getRoleAdmin"),
            args.span()
        )
            .unwrap_and_cast()
    }

    fn grant_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let mut args = array![];
        args.append_serde(role);
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selector!("grant_role"), selector!("grantRole"), args.span()
        )
            .unwrap_syscall();
    }

    fn revoke_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let mut args = array![];
        args.append_serde(role);
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selector!("revoke_role"), selector!("revokeRole"), args.span()
        )
            .unwrap_syscall();
    }

    fn renounce_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let mut args = array![];
        args.append_serde(role);
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address,
            selector!("renounce_role"),
            selector!("renounceRole"),
            args.span()
        )
            .unwrap_syscall();
    }

    fn supports_interface(self: @DualCaseAccessControl, interface_id: felt252) -> bool {
        let mut args = array![];
        args.append_serde(interface_id);

        try_selector_with_fallback(
            *self.contract_address,
            selector!("supports_interface"),
            selector!("supportsInterface"),
            args.span()
        )
            .unwrap_and_cast()
    }
}
