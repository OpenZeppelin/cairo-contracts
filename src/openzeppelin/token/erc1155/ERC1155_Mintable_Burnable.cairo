# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (token/erc1155/ERC1155_Mintable_Burnable.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.access.ownable import (
    Ownable_initializer,
    Ownable_only_owner
)
from openzeppelin.token.erc1155.library import (
    ERC1155,
    owner_or_approved 
)

from openzeppelin.introspection.ERC165 import ERC165

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(uri: felt, owner: felt):
    ERC1155.initializer(uri)
    Ownable_initializer(owner)
    return ()
end

#
# Getters
#

@view
func supportsInterface{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(interfaceId : felt) -> (success: felt):
    return ERC165.supports_interface(interfaceId)
end

@view
func uri{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}()
        -> (uri : felt):
    return ERC1155.uri()
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, id : Uint256) -> (balance : Uint256):
    return ERC1155.balance_of(account, id)
end

@view
func balanceOfBatch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        accounts_len : felt, accounts : felt*, ids_len : felt, ids : Uint256*)
        -> (balances_len : felt, balances : Uint256*):
    return ERC1155.balance_of_batch(accounts_len, accounts, ids_len, ids)
end

@view
func isApprovedForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, operator : felt) -> (is_approved : felt):
    return ERC1155.is_approved_for_all(account, operator)
end

#
# Externals
#

@external
func setApprovalForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt, approved : felt):
    ERC1155.set_approval_for_all(operator, approved)
    return ()
end

@external
func safeTransferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        from_ : felt, to : felt, id : Uint256, amount : Uint256, data_len : felt, data : felt*):
    ERC1155.safe_transfer_from(_from, to, id, amount, data_len, data)
    return ()
end


@external
func safeBatchTransferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _from : felt, to : felt, ids_len : felt, ids : Uint256*, amounts_len : felt, amounts : Uint256*,
        data_len : felt, data : felt*):
    ERC1155.safe_batch_transfer_from(
        _from, to, ids_len, ids, amounts_len, amounts, data_len, data)
    return ()
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, id : Uint256, amount : Uint256, data_len : felt, data : felt*):
    Ownable_only_owner()
    let (caller) = get_caller_address()
    with_attr error_message("ERC1155: called from zero address"):
        assert_not_zero(caller)
    end
    ERC1155._mint(to, id, amount, data_len, data)
    return ()
end

@external
func mintBatch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, ids_len : felt, ids : Uint256*, amounts_len : felt, amounts : Uint256*,
        data_len : felt, data : felt*):
    Ownable_only_owner()
    let (caller) = get_caller_address()
    with_attr error_message("ERC1155: called from zero address"):
        assert_not_zero(caller)
    end
    ERC1155._mint_batch(to, ids_len, ids, amounts_len, amounts, data_len, data)
    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
         _from : felt, id : Uint256, amount : Uint256):
    owner_or_approved(owner=_from)
    let (caller) = get_caller_address()
    with_attr error_message("ERC1155: called from zero address"):
        assert_not_zero(caller)
    end
    ERC1155._burn(_from, id, amount)
    return ()
end

@external
func burnBatch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _from : felt, ids_len : felt, ids : Uint256*, amounts_len : felt, amounts : Uint256*):
    owner_or_approved(owner=_from)
    let (caller) = get_caller_address()
    with_attr error_message("ERC1155: called from zero address"):
        assert_not_zero(caller)
    end
    ERC1155._burn_batch(_from, ids_len, ids, amounts_len, amounts)
    return ()
end

