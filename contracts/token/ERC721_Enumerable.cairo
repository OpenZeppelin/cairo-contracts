%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.token.ERC721_Enumerable_base import (
    ERC721_initializer,
    ERC721_approve, 
    ERC721_set_approval_for_all, 
    ERC721_transferFrom,
    ERC721_safeTransferFrom,
    ERC721_mint,
    ERC721_burn,

    ERC721_Enumerable_add_token_to_all_tokens_enumeration,
    ERC721_Enumerable_remove_token_from_all_tokens_enumeration,
    ERC721_Enumerable_add_token_to_owner_enumeration,
    ERC721_Enumerable_remove_token_from_owner_enumeration
)

from contracts.ERC165 import (
    ERC165_register_interface
)

from contracts.Ownable_base import (
    Ownable_initializer,
    Ownable_only_owner
)

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        owner: felt
    ):
    ERC721_initializer(name, symbol)
    Ownable_initializer(owner)
    # register IERC721_Enumerable
    ERC165_register_interface('0x780e9d63')
    return ()
end

#
# Externals
#

@external
func approve{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    ERC721_approve(to, token_id)
    return()
end

@external
func setApprovalForAll{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(operator: felt, approved: felt):
    ERC721_set_approval_for_all(operator, approved)
    return ()
end

@external
func transferFrom{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(
        _from: felt, 
        to: felt, 
        token_id: Uint256
    ):
    ERC721_transferFrom(_from, to, token_id)
    ERC721_Enumerable_remove_token_from_owner_enumeration(_from, token_id)
    ERC721_Enumerable_add_token_to_owner_enumeration(to, token_id)
    return ()
end

@external
func safeTransferFrom{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(
        _from: felt, 
        to: felt, 
        token_id: Uint256, 
        data: felt
    ):
    ERC721_safeTransferFrom(_from, to, token_id, data)
    ERC721_Enumerable_remove_token_from_owner_enumeration(_from, token_id)
    ERC721_Enumerable_add_token_to_owner_enumeration(to, token_id)
    return ()
end

#
# Mintable Methods
#

@external
func mint{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    Ownable_only_owner()
    ERC721_mint(to, token_id)
    ERC721_Enumerable_add_token_to_all_tokens_enumeration(token_id)
    ERC721_Enumerable_add_token_to_owner_enumeration(to, token_id)
    return ()
end

@external
func burn{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(_from: felt, token_id: Uint256):
    Ownable_only_owner()
    ERC721_burn(token_id)
    ERC721_Enumerable_remove_token_from_all_tokens_enumeration(token_id)
    ERC721_Enumerable_remove_token_from_owner_enumeration(_from, token_id)
    return ()
end
