%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_nn_le, assert_not_equal, assert_not_zero, assert_le
from starkware.cairo.common.alloc import alloc

#
# Storage
#

@storage_var
func balances(owner : felt, token_id : felt) -> (balance : felt):
end

@storage_var
func operator_approvals(owner : felt, operator : felt) -> (res : felt):
end

@storage_var
func initialized() -> (res : felt):
end

struct BlockchainNamespace:
    member a : felt
end

# ChainID. Chain Agnostic specifies that the length can go up to 32 nines (i.e. 9999999....) but we will only support 31 nines.
struct BlockchainReference:
    member a : felt
end

struct AssetNamespace:
    member a : felt
end

# Contract Address on L1. An address is represented using 20 bytes. Those bytes are written in the `felt`.
struct AssetReference:
    member a : felt
end

# ERC1155 returns the same URI for all token types.
# TokenId will be represented by the substring '{id}' and so stored in a felt
# Client calling the function must replace the '{id}' substring with the actual token type ID
struct TokenId:
    member a : felt
end

# As defined by Chain Agnostics (CAIP-29 and CAIP-19):
# {blockchain_namespace}:{blockchain_reference}/{asset_namespace}:{asset_reference}/{token_id}
# tokenId will be represented by the substring '{id}'
struct TokenUri:
    member blockchain_namespace : BlockchainNamespace
    member blockchain_reference : BlockchainReference
    member asset_namespace : AssetNamespace
    member asset_reference : AssetReference
    member token_id : TokenId
end

@storage_var
func URI() -> (res : TokenUri):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, token_ids_len : felt, token_ids : felt*, amounts_len : felt,
        amounts : felt*):
    # get_caller_address() returns '0' in the constructor;
    # therefore, recipient parameter is included
    ERC1155_mint_batch(recipient, token_ids_len, token_ids, amounts_len, amounts)

    # Set uri
    # SetURI(uri_)

    return ()
end

func SetURI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(uri_ : TokenUri):
    URI.write(uri_)
    return ()
end

#
# Getters
#

# Returns the same URI for all tokens type ID
# Client calling the function must replace the {id} substring with the actual token type ID
@view
func get_URI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        res : TokenUri):
    let (res) = URI.read()
    return (res)
end

@view
func balanceOf{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owner : felt, token_id : felt) -> (balance : felt):
    assert_not_zero(owner)
    let (balance) = balances.read(owner=owner, token_id=token_id)
    return (balance)
end

@view
func balanceOfBatch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owners_len : felt, owners : felt*, tokens_id_len : felt, tokens_id : felt*) -> (
        balance_len : felt, balance : felt*):
    assert owners_len = tokens_id_len
    alloc_locals
    local max = owners_len
    let (local ret_array : felt*) = alloc()
    local ret_index = 0
    populateBalanceOfBatch(owners, tokens_id, ret_array, ret_index, max)
    return (max, ret_array)
end

func populateBalanceOfBatch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owners : felt*, tokens_id : felt*, rett : felt*, ret_index : felt, max : felt):
    alloc_locals
    if ret_index == max:
        return ()
    end
    let (local retval0 : felt) = balances.read(owner=owners[0], token_id=tokens_id[0])
    rett[0] = retval0
    populateBalanceOfBatch(owners + 1, tokens_id + 1, rett + 1, ret_index + 1, max)
    return ()
end

#
# Approvals
#

@view
func isApprovedForAll{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        account : felt, operator : felt) -> (res : felt):
    let (res) = operator_approvals.read(owner=account, operator=operator)
    return (res=res)
end

@external
func setApprovalForAll{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        operator : felt, approved : felt):
    let (account) = get_caller_address()
    assert_not_equal(account, operator)

    # ensure approved is a boolean (0 or 1)
    assert approved * (1 - approved) = 0
    operator_approvals.write(account, operator, approved)
    return ()
end

#
# Transfer from
#

@external
func safeTransferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        sender : felt, recipient : felt, token_id : felt, amount : felt):
    assert_is_owner_or_approved(sender)
    ERC1155_transfer_from(sender, recipient, token_id, amount)
    return ()
end

@external
func safeBatchTransferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        sender : felt, recipient : felt, tokens_id_len : felt, tokens_id : felt*,
        amounts_len : felt, amounts : felt*):
    assert_is_owner_or_approved(sender)
    ERC1155_batch_transfer_from(sender, recipient, tokens_id_len, tokens_id, amounts_len, amounts)
    return ()
end

func ERC1155_transfer_from{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        sender : felt, recipient : felt, token_id : felt, amount : felt):
    # check recipient != 0
    assert_not_zero(recipient)

    # validate sender has enough funds
    let (sender_balance) = balances.read(owner=sender, token_id=token_id)
    assert_nn_le(amount, sender_balance)

    # substract from sender
    balances.write(sender, token_id, sender_balance - amount)

    # add to recipient
    let (res) = balances.read(owner=recipient, token_id=token_id)
    balances.write(recipient, token_id, res + amount)
    return ()
end

func ERC1155_batch_transfer_from{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, to : felt, tokens_id_len : felt, tokens_id : felt*, amounts_len : felt,
        amounts : felt*):
    assert tokens_id_len = amounts_len
    assert_not_zero(to)

    if tokens_id_len == 0:
        return ()
    end
    ERC1155_transfer_from(_from, to, [tokens_id], [amounts])

    return ERC1155_batch_transfer_from(
        _from=_from,
        to=to,
        tokens_id_len=tokens_id_len - 1,
        tokens_id=tokens_id + 1,
        amounts_len=amounts_len - 1,
        amounts=amounts + 1)
end

@external
func initialize_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        tokens_id_len : felt, tokens_id : felt*, amounts_len : felt, amounts : felt*,
        uri_ : TokenUri):
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)

    let (sender) = get_caller_address()
    ERC1155_mint_batch(sender, tokens_id_len, tokens_id, amounts_len, amounts)
    SetURI(uri_)

    return ()
end

#
# BURN
#

func ERC1155_mint{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        recipient : felt, token_id : felt, amount : felt) -> ():
    alloc_locals
    assert_not_zero(recipient)

    let (res) = balances.read(owner=recipient, token_id=token_id)

    balances.write(recipient, token_id, res + amount)

    return ()
end

func ERC1155_mint_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        recipient : felt, token_ids_len : felt, token_ids : felt*, amounts_len : felt,
        amounts : felt*) -> ():
    assert_not_zero(recipient)
    assert token_ids_len = amounts_len

    if token_ids_len == 0:
        return ()
    end

    ERC1155_mint(recipient, [token_ids], [amounts])

    return ERC1155_mint_batch(
        recipient=recipient,
        token_ids_len=token_ids_len - 1,
        token_ids=token_ids + 1,
        amounts_len=amounts_len - 1,
        amounts=amounts + 1)
end

#
# BURN
#

@external
func ERC1155_burn{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        account : felt, token_id : felt, amount : felt):
    assert_not_zero(account)

    let (from_balance) = balanceOf(account, token_id)

    assert_le(amount, from_balance)
    balances.write(account, token_id, from_balance - amount)

    return ()
end

@external
func ERC1155_burn_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        account : felt, token_ids_len : felt, token_ids : felt*, amounts_len : felt,
        amounts : felt*):
    assert_not_zero(account)
    assert token_ids_len = amounts_len

    if token_ids_len == 0:
        return ()
    end

    ERC1155_burn(account, [token_ids], [amounts])

    return ERC1155_burn_batch(
        account=account,
        token_ids_len=token_ids_len - 1,
        token_ids=token_ids + 1,
        amounts_len=amounts_len - 1,
        amounts=amounts + 1)
end

# HELPERS

func assert_is_owner_or_approved{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        address : felt):
    let (caller) = get_caller_address()

    if caller == address:
        return ()
    end

    let (operator_is_approved) = isApprovedForAll(account=address, operator=caller)
    assert operator_is_approved = 1
    return ()
end
