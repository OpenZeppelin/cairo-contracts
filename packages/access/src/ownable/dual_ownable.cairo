// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (access/ownable/dual_ownable.cairo)

use openzeppelin_utils::UnwrapAndCast;
use openzeppelin_utils::selectors;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

#[derive(Copy, Drop)]
pub struct DualCaseOwnable {
    pub contract_address: ContractAddress
}

pub trait DualCaseOwnableTrait {
    fn owner(self: @DualCaseOwnable) -> ContractAddress;
    fn transfer_ownership(self: @DualCaseOwnable, new_owner: ContractAddress);
    fn renounce_ownership(self: @DualCaseOwnable);
}

impl DualCaseOwnableImpl of DualCaseOwnableTrait {
    fn owner(self: @DualCaseOwnable) -> ContractAddress {
        let args = array![];

        call_contract_syscall(*self.contract_address, selectors::owner, args.span())
            .unwrap_and_cast()
    }

    fn transfer_ownership(self: @DualCaseOwnable, new_owner: ContractAddress) {
        let mut args = array![];
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
        let args = array![];

        try_selector_with_fallback(
            *self.contract_address,
            selectors::renounce_ownership,
            selectors::renounceOwnership,
            args.span()
        )
            .unwrap_syscall();
    }
}
