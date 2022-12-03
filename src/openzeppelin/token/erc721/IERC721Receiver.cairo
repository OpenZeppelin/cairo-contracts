// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.5.1 (token/erc721/IERC721Receiver.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC721Receiver {
    func onERC721Received(
        operator: felt, from_: felt, tokenId: Uint256, data_len: felt, data: felt*
    ) -> (selector: felt) {
    }
}
