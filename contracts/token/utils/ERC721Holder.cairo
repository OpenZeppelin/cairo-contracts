%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

#
# InterfaceId
#
const ERC721_RECEIVER_ID = '0x150b7a02'

@view
func onERC721Received{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        operator: felt,
        _from: felt,
        token_id: Uint256,
        data: felt
    ) -> (ret_val : felt): 
    return (ERC721_RECEIVER_ID)
end
