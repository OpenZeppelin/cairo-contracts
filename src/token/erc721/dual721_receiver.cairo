// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (token/erc721/dual721_receiver.cairo)

use array::ArrayTrait;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;

#[derive(Copy, Drop)]
struct DualCaseERC721Receiver {
    contract_address: ContractAddress
}

trait DualCaseERC721ReceiverTrait {
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
