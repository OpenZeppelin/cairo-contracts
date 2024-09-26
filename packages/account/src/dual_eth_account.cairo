// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (account/dual_eth_account.cairo)

use crate::interface::EthPublicKey;
use openzeppelin_utils::UnwrapAndCast;
use openzeppelin_utils::selectors;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

#[derive(Copy, Drop)]
pub struct DualCaseEthAccount {
    pub contract_address: ContractAddress
}

pub trait DualCaseEthAccountTrait {
    fn set_public_key(
        self: @DualCaseEthAccount, new_public_key: EthPublicKey, signature: Span<felt252>
    );
    fn get_public_key(self: @DualCaseEthAccount) -> EthPublicKey;
    fn is_valid_signature(
        self: @DualCaseEthAccount, hash: felt252, signature: Array<felt252>
    ) -> felt252;
    fn supports_interface(self: @DualCaseEthAccount, interface_id: felt252) -> bool;
}

impl DualCaseEthAccountImpl of DualCaseEthAccountTrait {
    fn set_public_key(
        self: @DualCaseEthAccount, new_public_key: EthPublicKey, signature: Span<felt252>
    ) {
        let mut args = array![];
        args.append_serde(new_public_key);
        args.append_serde(signature);

        try_selector_with_fallback(
            *self.contract_address, selectors::set_public_key, selectors::setPublicKey, args.span()
        )
            .unwrap_syscall();
    }

    fn get_public_key(self: @DualCaseEthAccount) -> EthPublicKey {
        let args = array![];

        try_selector_with_fallback(
            *self.contract_address, selectors::get_public_key, selectors::getPublicKey, args.span()
        )
            .unwrap_and_cast()
    }

    fn is_valid_signature(
        self: @DualCaseEthAccount, hash: felt252, signature: Array<felt252>
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

    fn supports_interface(self: @DualCaseEthAccount, interface_id: felt252) -> bool {
        let args = array![interface_id];

        call_contract_syscall(*self.contract_address, selectors::supports_interface, args.span())
            .unwrap_and_cast()
    }
}
