// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (token/erc1155/presets/utils/ERC1155Holder.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.utils.constants.library import (
    IERC1155_RECEIVER_ID,
    ON_ERC1155_RECEIVED_SELECTOR,
    ON_ERC1155_BATCH_RECEIVED_SELECTOR,
)

@view
func onERC1155Received(
    operator: felt, from_: felt, id: Uint256, value: Uint256, data_len: felt, data: felt*
) -> (selector: felt) {
    if (data_len == 0) {
        return (ON_ERC1155_RECEIVED_SELECTOR,);
    } else {
        return (FALSE,);
    }
}

@view
func onERC1155BatchReceived(
    operator: felt,
    from_: felt,
    ids_len: felt,
    ids: Uint256*,
    values_len: felt,
    values: Uint256*,
    data_len: felt,
    data: felt*,
) -> (selector: felt) {
    if (data_len == 0) {
        return (ON_ERC1155_BATCH_RECEIVED_SELECTOR,);
    } else {
        return (FALSE,);
    }
}

@view
func supportsInterface(interfaceId: felt) -> (success: felt) {
    if (interfaceId == IERC1155_RECEIVER_ID) {
        return (TRUE,);
    } else {
        return (FALSE,);
    }
}
