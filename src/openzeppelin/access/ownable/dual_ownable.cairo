use array::SpanTrait;
use array::ArrayTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use traits::TryInto;

use openzeppelin::utils::Felt252TryIntoBool;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use openzeppelin::utils::UnwrapAndCast;

#[derive(Copy, Drop)]
struct DualCaseOwnable {
    contract_address: ContractAddress
}

trait DualCaseOwnableTrait {
    fn owner(self: @DualCaseOwnable) -> ContractAddress;
    fn transfer_ownership(self: @DualCaseOwnable, new_owner: ContractAddress);
    fn renounce_ownership(self: @DualCaseOwnable);
}

impl DualCaseOwnableImpl of DualCaseOwnableTrait {
    fn owner(self: @DualCaseOwnable) -> ContractAddress {
        let args = ArrayTrait::new();

        call_contract_syscall(*self.contract_address, selectors::owner, args.span())
            .unwrap_and_cast()
    }

    fn transfer_ownership(self: @DualCaseOwnable, new_owner: ContractAddress) {
        let mut args = ArrayTrait::new();
        args.append_serde(new_owner);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::transfer_ownership,
            selectors::transferOwnership,
            args.span()
        )
            .unwrap_syscall();
    }

    fn renounce_ownership(self: @DualCaseOwnable) {
        let mut args = ArrayTrait::new();

        try_selector_with_fallback(
            *self.contract_address,
            selectors::renounce_ownership,
            selectors::renounceOwnership,
            args.span()
        )
            .unwrap_syscall();
    }
}
