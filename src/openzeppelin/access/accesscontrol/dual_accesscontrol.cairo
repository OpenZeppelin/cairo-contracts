
use array::SpanTrait;
use array::ArrayTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use traits::Into;
use traits::TryInto;

use openzeppelin::utils::try_selector_with_fallback;
use openzeppelin::utils::Felt252TryIntoBool;
use openzeppelin::utils::constants;

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
        let snake_selector = constants::HAS_ROLE_SELECTOR;
        let camel_selector = constants::HASROLE_SELECTOR;

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
        let snake_selector = constants::GET_ROLE_ADMIN_SELECTOR;
        let camel_selector = constants::GETROLEADMIN_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(role);

        *try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall()
            .at(0)
    }

    fn grant_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = constants::GRANT_ROLE_SELECTOR;
        let camel_selector = constants::GRANTROLE_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }

    fn revoke_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = constants::REVOKE_ROLE_SELECTOR;
        let camel_selector = constants::REVOKEROLE_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }

    fn renounce_role(self: @DualCaseAccessControl, role: felt252, account: ContractAddress) {
        let snake_selector = constants::RENOUNCE_ROLE_SELECTOR;
        let camel_selector = constants::RENOUNCEROLE_SELECTOR;

        let mut args = ArrayTrait::new();
        args.append(role);
        args.append(account.into());

        try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();
    }
}
