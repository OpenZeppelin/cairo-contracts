// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.10.0 (token/erc1155/dual1155_receiver.cairo)

use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;

#[derive(Copy, Drop)]
struct DualCaseERC1155Receiver {
    contract_address: ContractAddress
}

trait DualCaseERC1155ReceiverTrait {
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
