%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

@view
func onERC721Received{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        operator: felt,
        _from: felt,
        token_id: Uint256,
        data_len: felt,
        data: felt*
    ) -> (selector: felt): 
    # ERC721_RECEIVER_ID
    return ('0x150b7a02')
end

# ERC721's `safeTransferFrom` requires a means of differentiating between account and
# non-account contracts. Currently, StarkNet does not support error handling from the
# contract level; therefore, this ERC721 implementation requires that all contracts that
# support safe ERC721 transfers (both accounts and non-accounts) include the `is_account` 
# method. This method should return `0` since this contract is NOT an account.
@view
func is_account{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }() -> (res: felt):
    return (0)
end
