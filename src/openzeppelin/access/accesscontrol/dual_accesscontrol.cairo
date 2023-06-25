use array::ArrayTrait;
use array::SpanTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::SyscallResultTrait;
use traits::Into;
use traits::TryInto;

use openzeppelin::utils::constants;
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
        let snake_selector = constants::has_role_SELECTOR;
        let camel_selector = constants::hasRole_SELECTOR;

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
        let snake_selector = constants::get_role_admin_SELECTOR;
        let camel_selector = constants::getRoleAdmin_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(role);

        *try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall()
            .at(0)
    }

    fn grant_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = constants::grant_role_SELECTOR;
        let camel_selector = constants::grantRole_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }

    fn revoke_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = constants::revoke_role_SELECTOR;
        let camel_selector = constants::revokeRole_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }

    fn renounce_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = constants::renounce_role_SELECTOR;
        let camel_selector = constants::renounceRole_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }
}
