%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.token.ERC721_base import (
    _exists
)

from contracts.ERC165_base import (
    ERC165_register_interface
)

#
# Storage
#

@storage_var
func ERC721_token_uri(token_id: Uint256) -> (token_uri: felt):
end

#
# Constructor
#

func ERC721_Metadata_initializer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # register IERC721_Metadata
    ERC165_register_interface('0x5b5e139f')
    return ()
end

func ERC721_Metadata_tokenURI{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token_id: Uint256) -> (token_uri: felt):
    let (exists) = _exists(token_id)
    assert exists = 1

    # if tokenURI is not set, it will return 0
    let (token_uri) = ERC721_token_uri.read(token_id)
    return (token_uri)
end

func ERC721_Metadata_setTokenURI{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token_id: Uint256, token_uri: felt):
    let (exists) = _exists(token_id)
    assert exists = 1

    ERC721_token_uri.write(token_id, token_uri)
    return ()
end
