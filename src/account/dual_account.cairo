// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (account/dual_account.cairo)

use array::ArrayTrait;
use array::SpanTrait;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;

#[derive(Copy, Drop)]
struct DualCaseAccount {
    contract_address: ContractAddress
}

trait DualCaseAccountABI {
    fn set_public_key(self: @DualCaseAccount, new_public_key: felt252);
    fn get_public_key(self: @DualCaseAccount) -> felt252;
    fn is_valid_signature(
        self: @DualCaseAccount, hash: felt252, signature: Array<felt252>
    ) -> felt252;
    fn supports_interface(self: @DualCaseAccount, interface_id: felt252) -> bool;
}

impl DualCaseAccountImpl of DualCaseAccountABI {
    fn set_public_key(self: @DualCaseAccount, new_public_key: felt252) {
        let mut args = array![new_public_key];

        try_selector_with_fallback(
            *self.contract_address, selectors::set_public_key, selectors::setPublicKey, args.span()
        )
            .unwrap_syscall();
    }

    fn get_public_key(self: @DualCaseAccount) -> felt252 {
        let mut args = array![];

        try_selector_with_fallback(
            *self.contract_address, selectors::get_public_key, selectors::getPublicKey, args.span()
        )
            .unwrap_and_cast()
    }

    fn is_valid_signature(
        self: @DualCaseAccount, hash: felt252, signature: Array<felt252>
    ) -> felt252 {
        let mut args = array![hash];
        args.append_serde(signature);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::is_valid_signature,
            selectors::isValidSignature,
            args.span()
        )
            .unwrap_and_cast()
    }

    fn supports_interface(self: @DualCaseAccount, interface_id: felt252) -> bool {
        let mut args = array![interface_id];

        try_selector_with_fallback(
            *self.contract_address,
            selectors::supports_interface,
            selectors::supportsInterface,
            args.span()
        )
            .unwrap_and_cast()
    }
}
