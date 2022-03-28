# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (token/erc721/utils/ERC721_Holder.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.utils.constants import IERC721_RECEIVER_ID

from openzeppelin.introspection.ERC165 import (
    ERC165_supports_interface,
    ERC165_register_interface
)

@view
func onERC721Received(
        operator: felt,
        from_: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*
    ) -> (selector: felt): 
    return (IERC721_RECEIVER_ID)
end

@view
func supportsInterface{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(interfaceId: felt) -> (success: felt):
    let (success) = ERC165_supports_interface(interfaceId)
    return (success)
end

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    ERC165_register_interface(IERC721_RECEIVER_ID)
    return ()
end
