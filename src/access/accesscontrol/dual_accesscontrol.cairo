use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;

use openzeppelin::utils::Felt252TryIntoBool;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use openzeppelin::utils::UnwrapAndCast;

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

        try_selector_with_fallback(
            *self.contract_address,
            selectors::supports_interface,
            selectors::supportsInterface,
            args.span()
        )
            .unwrap_and_cast()
    }
}
