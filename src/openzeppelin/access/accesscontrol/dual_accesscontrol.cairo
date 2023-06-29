use array::ArrayTrait;
use array::SpanTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::SyscallResultTrait;
use traits::Into;
use traits::TryInto;

use openzeppelin::utils::selectors;
use openzeppelin::utils::Felt252TryIntoBool;
use openzeppelin::utils::try_selector_with_fallback;


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
}

impl DualCaseAccessControlImpl of DualCaseAccessControlTrait {
    fn has_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) -> bool {
        let snake_selector = selectors::has_role;
        let camel_selector = selectors::hasRole;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        (*try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }

    fn get_role_admin(self: @DualCaseAccessControl, role: felt252) -> felt252 {
        let snake_selector = selectors::get_role_admin;
        let camel_selector = selectors::getRoleAdmin;

        let mut args = ArrayTrait::new();
        args.append(role);

        *try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall()
            .at(0)
    }

    fn grant_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = selectors::grant_role;
        let camel_selector = selectors::grantRole;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }

    fn revoke_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = selectors::revoke_role;
        let camel_selector = selectors::revokeRole;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }

    fn renounce_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = selectors::renounce_role;
        let camel_selector = selectors::renounceRole;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }
}
