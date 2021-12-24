%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_eq
)

from contracts.token.ERC721_base import (
    ERC721_initializer,
    ERC721_approve, 
    ERC721_set_approval_for_all, 
    ERC721_transferFrom,
    ERC721_safeTransferFrom,
    ERC721_mint,
    ERC721_burn,
    balanceOf
)

#
# Storage
#

@storage_var
func all_tokens_len() -> (res: Uint256):
end

@storage_var
func all_tokens_list(index_low: felt, index_high: felt) -> (token_id: Uint256):
end

@storage_var
func all_tokens_index(token_id_low: felt, token_id_high: felt) -> (index: Uint256):
end

@storage_var
func owned_tokens(owner: felt, index_low: felt, index_high: felt) -> (token_id: Uint256):
end

@storage_var
func owned_tokens_index(token_id_low: felt, token_id_high: felt) -> (index: Uint256):
end

#
# Getters
#

@view
func totalSupply{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply) = all_tokens_len.read()
    return (totalSupply)
end


@view
func tokenByIndex{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(index: Uint256) -> (token_id: Uint256):
    alloc_locals
    # Ensures index argument is less than total_supply 
    let (len: Uint256) = all_tokens_len.read()
    let (is_lt) = uint256_le(index, len)
    assert is_lt = 1

    let (token_id: Uint256) = all_tokens_list.read(index.low, index.high)
    return (token_id)
end

@view
func tokenOfOwnerByIndex{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(owner: felt, index: Uint256) -> (token_id: Uint256):
    alloc_locals
    # Ensures index argument is less than total_supply 
    let (len: Uint256) = all_tokens_len.read()
    let (is_lt) = uint256_le(index, len)
    assert is_lt = 1

    let (token_id: Uint256) = owned_tokens.read(owner, index.low, index.high)
    return (token_id)
end

#
# Externals
#

func ERC721_Enumerable_add_token_to_all_tokens_enumeration{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(token_id: Uint256):
    alloc_locals
    # Update all_tokens_len
    let (supply: Uint256) = all_tokens_len.read()
    let (local new_supply: Uint256, _) = uint256_add(supply, Uint256(1, 0))
    all_tokens_len.write(new_supply)

    # Update all_tokens_list
    all_tokens_list.write(new_supply.low, new_supply.high, token_id)

    # Update all_tokens_index
    all_tokens_index.write(token_id.low, token_id.high, new_supply)
    return ()
end

func ERC721_Enumerable_remove_token_from_all_tokens_enumeration{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(token_id: Uint256):
    alloc_locals
    let (supply: Uint256) = all_tokens_len.read()
    let (local index_from_id: Uint256) = all_tokens_index.read(token_id.low, token_id.high)
    let (local last_token_id: Uint256) = all_tokens_list.read(supply.low, supply.high)

    # Update all_tokens_list i.e. index n => token_id
    all_tokens_list.write(index_from_id.low, index_from_id.high, last_token_id)

    # Update all_tokens_index i.e. token_id => index n
    all_tokens_index.write(last_token_id.low, last_token_id.high, index_from_id)

    # Update totalSupply
    let (local new_supply: Uint256) = uint256_sub(supply, Uint256(1, 0))
    all_tokens_len.write(new_supply)
    return ()
end

func ERC721_Enumerable_add_token_to_owner_enumeration{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    alloc_locals
    let (local length: Uint256) = balanceOf(to) 
    owned_tokens.write(to, length.low, length.high, token_id)
    owned_tokens_index.write(token_id.low, token_id.high, length)
    return ()
end

func ERC721_Enumerable_remove_token_from_owner_enumeration{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(_from: felt, token_id: Uint256):
    alloc_locals
    let (local last_token_index: Uint256) = balanceOf(_from)
    let (local token_index: Uint256) = owned_tokens_index.read(token_id.low, token_id.high)

    # If index is last, we can just set the return values to zero
    let (is_equal) = uint256_eq(token_index, last_token_index)
    if is_equal == 1:
        owned_tokens_index.write(token_id.low, token_id.high, Uint256(0, 0))
        owned_tokens.write(_from, last_token_index.low, last_token_index.high, Uint256(0, 0))
        return ()
    end

   # If index is not last, reposition owner's last token to the removed token's index
    let (last_token_id: Uint256) = owned_tokens.read(_from, last_token_index.low, last_token_index.high)
    owned_tokens.write(_from, token_index.low, token_index.high, last_token_id)
    owned_tokens_index.write(last_token_id.low, last_token_id.high, token_index)
    return ()
end
