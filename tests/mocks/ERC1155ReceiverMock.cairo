# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.utils.constants.library import (
    IERC1155_RECEIVER_ID,
    IACCOUNT_ID,
    ON_ERC1155_RECEIVED_SELECTOR,
    ON_ERC1155_BATCH_RECEIVED_SELECTOR
)

@external
func onERC1155Received(
        operator : felt,
        from_ : felt,
        id : Uint256,
        amount : Uint256,
        data_len : felt,
        data : felt*
    ) -> (selector : felt):
    if data_len == 0:
        return (ON_ERC1155_RECEIVED_SELECTOR)
    else:
        return (0)
    end
end

@external
func onERC1155BatchReceived(
        operator : felt,
        from_ : felt,
        ids_len : felt,
        ids : Uint256*, 
        amounts_len : felt,
        amounts : Uint256*,
        data_len : felt,
        data : felt*
    ) -> (selector : felt):
    if data_len == 0:
        return (ON_ERC1155_BATCH_RECEIVED_SELECTOR)
    else:
        return (0)
    end
end

@external
func supportsInterface(interfaceId : felt) -> (success : felt):
    if interfaceId == IERC1155_RECEIVER_ID:
        return (TRUE)
    else:
        return (FALSE)
    end
end
