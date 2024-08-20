// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (token/erc1155/dual1155_receiver.cairo)

use openzeppelin_utils::UnwrapAndCast;
use openzeppelin_utils::selectors;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::try_selector_with_fallback;
use starknet::ContractAddress;

#[derive(Copy, Drop)]
pub struct DualCaseERC1155Receiver {
    pub contract_address: ContractAddress
}

pub trait DualCaseERC1155ReceiverTrait {
    fn on_erc1155_received(
        self: @DualCaseERC1155Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252;

    fn on_erc1155_batch_received(
        self: @DualCaseERC1155Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252;
}

impl DualCaseERC1155ReceiverImpl of DualCaseERC1155ReceiverTrait {
    fn on_erc1155_received(
        self: @DualCaseERC1155Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252 {
        let mut args = array![];
        args.append_serde(operator);
        args.append_serde(from);
        args.append_serde(token_id);
        args.append_serde(value);
        args.append_serde(data);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::on_erc1155_received,
            selectors::onERC1155Received,
            args.span()
        )
            .unwrap_and_cast()
    }

    fn on_erc1155_batch_received(
        self: @DualCaseERC1155Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252 {
        let mut args = array![];
        args.append_serde(operator);
        args.append_serde(from);
        args.append_serde(token_ids);
        args.append_serde(values);
        args.append_serde(data);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::on_erc1155_batch_received,
            selectors::onERC1155BatchReceived,
            args.span()
        )
            .unwrap_and_cast()
    }
}
