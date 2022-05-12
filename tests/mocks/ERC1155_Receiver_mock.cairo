%lang starknet
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.utils.constants import (
    IERC1155_RECEIVER_ID, IACCOUNT_ID, ON_ERC1155_RECEIVED_SELECTOR, ON_ERC1155_BATCH_RECEIVED_SELECTOR 
)

@external
func onERC1155Received(
            operator : felt, _from : felt, id : Uint256, value : Uint256,
            data_len : felt, data : felt*) -> (selector : felt):
    if data_len == 0:
        return (ON_ERC1155_RECEIVED_SELECTOR)
    else:
        return (FALSE)
    end
end

@external
func onERC1155BatchReceived(
        operator : felt, _from : felt, ids_len : felt, ids : Uint256*, 
        values_len : felt, values : Uint256*, data_len : felt, data : felt*)
        -> (selector : felt):
    if data_len == 0:
        return (ON_ERC1155_RECEIVED_SELECTOR)
    else:
        return (0)
    end
end

@external
func supportsInterface(interfaceId : felt) -> (success : felt):
    if interfaceId == IERC1155_RECEIVER_ID:
        return (1)
    else:
        return (0)
    end
end
