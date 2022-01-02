%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.token.ERC721_base import (
    ERC721_name_,
    ERC721_symbol_,
    ERC721_balanceOf,
    ERC721_ownerOf,
    ERC721_getApproved,
    ERC721_isApprovedForAll,
    ERC721_tokenURI,

    ERC721_initializer,
    ERC721_approve, 
    ERC721_setApprovalForAll, 
    ERC721_transferFrom,
    ERC721_safeTransferFrom,
    ERC721_mint,
    ERC721_set_baseURI
)

from contracts.ERC165 import (
    ERC165_register_interface
)

#
# Constructor
#

func ERC721_Metadata_initializer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(name: felt, symbol: felt, base_uri: felt):
    # register IERC721_Metadata
    ERC721_initializer(name, symbol)
    ERC165_register_interface('0x5b5e139f')
    ERC721_set_baseURI(base_uri)
    return ()
end

