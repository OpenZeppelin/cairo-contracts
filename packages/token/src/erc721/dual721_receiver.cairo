// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.16.0 (token/erc721/dual721_receiver.cairo)

use openzeppelin_utils::UnwrapAndCast;
use openzeppelin_utils::selectors;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::try_selector_with_fallback;
use starknet::ContractAddress;

#[derive(Copy, Drop)]
pub struct DualCaseERC721Receiver {
    pub contract_address: ContractAddress
}

pub trait DualCaseERC721ReceiverTrait {
    fn on_erc721_received(
        self: @DualCaseERC721Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252;
}

impl DualCaseERC721ReceiverImpl of DualCaseERC721ReceiverTrait {
    fn on_erc721_received(
        self: @DualCaseERC721Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252 {
        let mut args = array![];
        args.append_serde(operator);
        args.append_serde(from);
        args.append_serde(token_id);
        args.append_serde(data);

        try_selector_with_fallback(
            *self.contract_address,
            selectors::on_erc721_received,
            selectors::onERC721Received,
            args.span()
        )
            .unwrap_and_cast()
    }
}
