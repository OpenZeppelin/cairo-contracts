// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (account/dual_eth_account.cairo)

use openzeppelin::account::interface::EthPublicKey;
use openzeppelin::account::utils::secp256k1::Secp256k1PointSerde;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;

#[derive(Copy, Drop)]
struct DualCaseEthAccount {
    contract_address: ContractAddress
}

trait DualCaseEthAccountABI {
    fn set_public_key(self: @DualCaseEthAccount, new_public_key: EthPublicKey);
    fn get_public_key(self: @DualCaseEthAccount) -> EthPublicKey;
    fn is_valid_signature(
        self: @DualCaseEthAccount, hash: felt252, signature: Array<felt252>
    ) -> felt252;
    fn supports_interface(self: @DualCaseEthAccount, interface_id: felt252) -> bool;
}

impl DualCaseEthAccountImpl of DualCaseEthAccountABI {
    fn set_public_key(self: @DualCaseEthAccount, new_public_key: EthPublicKey) {
        let mut args = array![];
        new_public_key.serialize(ref args);

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
