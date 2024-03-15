// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.10.0 (token/erc1155/dual1155.cairo)

use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;

#[derive(Copy, Drop)]
struct DualCaseERC1155 {
    contract_address: ContractAddress
}

trait DualCaseERC1155Trait {
    fn uri(self: @DualCaseERC1155, token_id: u256) -> ByteArray;
    fn balance_of(self: @DualCaseERC1155, account: ContractAddress, token_id: u256) -> u256;
    fn balance_of_batch(
        self: @DualCaseERC1155, accounts: Span<ContractAddress>, token_ids: Span<u256>
    ) -> Span<u256>;
    fn safe_transfer_from(
        self: @DualCaseERC1155,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    );
    fn safe_batch_transfer_from(
        self: @DualCaseERC1155,
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    );
    fn is_approved_for_all(
        self: @DualCaseERC1155, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn set_approval_for_all(self: @DualCaseERC1155, operator: ContractAddress, approved: bool);
    fn supports_interface(self: @DualCaseERC1155, interface_id: felt252) -> bool;
}

impl DualCaseERC1155Impl of DualCaseERC1155Trait {
    fn uri(self: @DualCaseERC1155, token_id: u256) -> ByteArray {
        let mut args = array![];
        args.append_serde(token_id);

        call_contract_syscall(*self.contract_address, selectors::uri, args.span()).unwrap_and_cast()
    }

    fn balance_of(self: @DualCaseERC1155, account: ContractAddress, token_id: u256) -> u256 {
        let mut args = array![];
        args.append_serde(account);
        args.append_serde(token_id);

        try_selector_with_fallback(
            *self.contract_address, selectors::balance_of, selectors::balanceOf, args.span()
        )
            .unwrap_and_cast()
    }

    fn balance_of_batch(
        self: @DualCaseERC1155, accounts: Span<ContractAddress>, token_ids: Span<u256>
    ) -> Span<u256> {
        let mut args = array![];
        args.append_serde(accounts);
        args.append_serde(token_ids);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::balance_of_batch,
            selectors::balanceOfBatch,
            args.span()
        )
            .unwrap_and_cast()
    }

    fn safe_transfer_from(
        self: @DualCaseERC1155,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    ) {
        let mut args = array![];
        args.append_serde(from);
        args.append_serde(to);
        args.append_serde(token_id);
        args.append_serde(value);
        args.append_serde(data);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::safe_transfer_from,
            selectors::safeTransferFrom,
            args.span()
        )
            .unwrap_syscall();
    }

    fn safe_batch_transfer_from(
        self: @DualCaseERC1155,
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) {
        let mut args = array![];
        args.append_serde(from);
        args.append_serde(to);
        args.append_serde(token_ids);
        args.append_serde(values);
        args.append_serde(data);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::safe_batch_transfer_from,
            selectors::safeBatchTransferFrom,
            args.span()
        )
            .unwrap_syscall();
    }

    fn is_approved_for_all(
        self: @DualCaseERC1155, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        let mut args = array![];
        args.append_serde(owner);
        args.append_serde(operator);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::is_approved_for_all,
            selectors::isApprovedForAll,
            args.span()
        )
            .unwrap_and_cast()
    }

    fn set_approval_for_all(self: @DualCaseERC1155, operator: ContractAddress, approved: bool) {
        let mut args = array![];
        args.append_serde(operator);
        args.append_serde(approved);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::set_approval_for_all,
            selectors::setApprovalForAll,
            args.span()
        )
            .unwrap_syscall();
    }

    fn supports_interface(self: @DualCaseERC1155, interface_id: felt252) -> bool {
        let mut args = array![];
        args.append_serde(interface_id);

        call_contract_syscall(*self.contract_address, selectors::supports_interface, args.span())
            .unwrap_and_cast()
    }
}
