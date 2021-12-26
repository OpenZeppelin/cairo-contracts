%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_nn_le, assert_not_equal, assert_not_zero, assert_le
from starkware.cairo.common.alloc import alloc

from contracts.token.ERC1155.ERC1155_struct import TokenUri

from contracts.token.ERC1155.ERC1155_base import (
    ERC1155_initializer,
    ERC1155_transfer_from,
    ERC1155_batch_transfer_from,
    ERC1155_mint,
    ERC1155_mint_batch,
    ERC1155_burn,
    ERC1155_burn_batch,
    ERC1155_URI,
    ERC1155_set_approval_for_all,
    ERC1155_balances,
    ERC1155_assert_is_owner_or_approved
)

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt,
        token_ids_len : felt, 
        token_ids : felt*, 
        amounts_len : felt,
        amounts : felt*):
    ERC1155_initializer(recipient, token_ids_len, token_ids, amounts_len, amounts)
    return ()
end

#
# Externals
#

@external
func SetURI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(uri_ : TokenUri):
    ERC1155_URI.write(uri_)
    return ()
end

@external
func setApprovalForAll{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        operator : felt, approved : felt):
    let (account) = get_caller_address()
    ERC1155_set_approval_for_all(operator, approved)
    return ()
end

@external
func safeTransferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        sender : felt, recipient : felt, token_id : felt, amount : felt):
    ERC1155_assert_is_owner_or_approved(sender)
    ERC1155_transfer_from(sender, recipient, token_id, amount)
    return ()
end

@external
func safeBatchTransferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        sender : felt, recipient : felt, tokens_id_len : felt, tokens_id : felt*,
        amounts_len : felt, amounts : felt*):
    ERC1155_assert_is_owner_or_approved(sender)
    ERC1155_batch_transfer_from(sender, recipient, tokens_id_len, tokens_id, amounts_len, amounts)
    return ()
end


@external
func mint{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        recipient : felt, token_id : felt, amount : felt) -> ():
    ERC1155_mint(recipient, token_id, amount)

    return ()
end

@external
func mint_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        recipient : felt, token_ids_len : felt, token_ids : felt*, amounts_len : felt,
        amounts : felt*) -> ():
    ERC1155_mint_batch(recipient, token_ids_len, token_ids, amounts_len, amounts)

    return ()
end

@external
func burn{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        account : felt, token_id : felt, amount : felt):
    ERC1155_burn(account, token_id, amount)

    return ()
end

@external
func burn_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        account : felt, token_ids_len : felt, token_ids : felt*, amounts_len : felt,
        amounts : felt*):
    ERC1155_burn_batch(account, token_ids_len, token_ids, amounts_len, amounts)

    return ()
end
