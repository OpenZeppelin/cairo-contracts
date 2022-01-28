%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.ERC165_base import (
    ERC165_supports_interface,
    ERC165_register_interface
)

@view
func onERC721Received{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        operator: felt,
        _from: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*
    ) -> (selector: felt): 
    # ERC721_RECEIVER_ID = 0x150b7a02
    return (0x150b7a02)
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
    # ERC721_RECEIVER_ID = 0x150b7a02
    ERC165_register_interface(0x150b7a02)
    return ()
end
