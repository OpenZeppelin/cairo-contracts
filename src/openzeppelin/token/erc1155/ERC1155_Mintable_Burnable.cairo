%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.access.ownable import (
    Ownable_initializer,
    Ownable_only_owner
)
from openzeppelin.token.erc1155.library import (
    ERC1155_uri,
    ERC1155_balanceOf,
    ERC1155_balanceOfBatch,
    ERC1155_isApprovedForAll,

    ERC1155_initializer,
    ERC1155_setApprovalForAll,
    ERC1155_safeTransferFrom,
    ERC1155_safeBatchTransferFrom,
    ERC1155_mint,
    ERC1155_mint_batch,
    ERC1155_burn,
    ERC1155_burn_batch,
    
    owner_or_approved 
)

from openzeppelin.introspection.ERC165 import ERC165_supports_interface

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        uri,owner):
    ERC1155_initializer(uri)
    Ownable_initializer(owner)
    return ()
end

#
# Getters
#

@view
func supportsInterface{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(interfaceId : felt) -> (is_supported : felt):
    return ERC165_supports_interface(interfaceId)
end

@view
func uri{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}()
        -> (uri : felt):
    return ERC1155_uri()
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, id : Uint256) -> (balance : Uint256):
    return ERC1155_balanceOf(account,id)
end

@view
func balanceOfBatch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        accounts_len : felt, accounts : felt*, ids_len : felt, ids : Uint256*)
        -> (balances_len : felt, balances : Uint256*):
    return ERC1155_balanceOfBatch(accounts_len,accounts,ids_len,ids)
end

@view
func isApprovedForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, operator : felt) -> (is_approved : felt):
    return ERC1155_isApprovedForAll(account, operator)
end

#
# Externals
#

@external
func setApprovalForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt, approved : felt):
    ERC1155_setApprovalForAll(operator, approved)
    return ()
end

@external
func safeTransferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _from : felt, to : felt, id : Uint256, amount : Uint256, data_len : felt, data : felt*):
    ERC1155_safeTransferFrom(_from, to, id, amount, data_len, data)
    return ()
end


@external
func safeBatchTransferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _from : felt, to : felt, ids_len : felt, ids : Uint256*, amounts_len : felt, amounts : Uint256*,
        data_len : felt, data : felt*):
    ERC1155_safeBatchTransferFrom(
        _from, to, ids_len, ids, amounts_len, amounts, data_len, data)
    return ()
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, id : Uint256, amount : Uint256, data_len : felt, data : felt*):
    Ownable_only_owner()
    ERC1155_mint(to, id, amount, data_len, data)
    return ()
end

@external
func mintBatch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, ids_len : felt, ids : Uint256*, amounts_len : felt, amounts : Uint256*,
        data_len : felt, data : felt*):
    Ownable_only_owner()
    ERC1155_mint_batch(to, ids_len, ids, amounts_len, amounts, data_len, data)
    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
         _from : felt, id : Uint256, amount : Uint256):
    owner_or_approved(owner=_from)
    ERC1155_burn(_from, id, amount)
    return ()
end

@external
func burnBatch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _from : felt, ids_len : felt, ids : Uint256*, amounts_len : felt, amounts : Uint256*):
    owner_or_approved(owner=_from)
    ERC1155_burn_batch(_from, ids_len, ids, amounts_len, amounts)
    return ()
end


