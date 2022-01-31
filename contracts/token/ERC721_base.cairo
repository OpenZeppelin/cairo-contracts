%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256, uint256_check

from contracts.utils.safemath import (
    uint256_checked_add,
    uint256_checked_sub_le
)

from contracts.ERC165_base import ERC165_register_interface

from contracts.token.IERC721_Receiver import IERC721_Receiver

from contracts.IERC165 import IERC165

from contracts.utils.constants import TRUE, FALSE

#
# Storage
#

@storage_var
func ERC721_name_() -> (name: felt):
end

@storage_var
func ERC721_symbol_() -> (symbol: felt):
end

@storage_var
func ERC721_owners(token_id: Uint256) -> (owner: felt):
end

@storage_var
func ERC721_balances(account: felt) -> (balance: Uint256):
end

@storage_var
func ERC721_token_approvals(token_id: Uint256) -> (res: felt):
end

@storage_var
func ERC721_operator_approvals(owner: felt, operator: felt) -> (res: felt):
end

@storage_var
func ERC721_token_uri(token_id: Uint256) -> (token_uri: felt):
end

#
# Constructor
#

func ERC721_initializer{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
    ):
    ERC721_name_.write(name)
    ERC721_symbol_.write(symbol)
    # register IERC721
    ERC165_register_interface(0x80ac58cd)
    # register IERC721_Metadata
    ERC165_register_interface(0x5b5e139f)
    return ()
end

#
# Getters
#

func ERC721_name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = ERC721_name_.read()
    return (name)
end

func ERC721_symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = ERC721_symbol_.read()
    return (symbol)
end

func ERC721_balanceOf{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt) -> (balance: Uint256):
    let (balance: Uint256) = ERC721_balances.read(owner)
    assert_not_zero(owner)
    return (balance)
end

func ERC721_ownerOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256) -> (owner: felt):
    uint256_check(token_id)
    let (owner) = ERC721_owners.read(token_id)
    # Ensuring the query is not for nonexistent token
    assert_not_zero(owner)
    return (owner)
end

func ERC721_getApproved{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256) -> (approved: felt):
    uint256_check(token_id)
    let (exists) = _exists(token_id)
    assert exists = TRUE

    let (approved) = ERC721_token_approvals.read(token_id)
    return (approved)
end

func ERC721_isApprovedForAll{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt, operator: felt) -> (is_approved: felt):
    let (is_approved) = ERC721_operator_approvals.read(owner=owner, operator=operator)
    return (is_approved)
end

func ERC721_tokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256) -> (token_uri: felt):
    let (exists) = _exists(token_id)
    assert exists = TRUE

    # if tokenURI is not set, it will return 0
    let (token_uri) = ERC721_token_uri.read(token_id)
    return (token_uri)
end

#
# Externals
#

func ERC721_approve{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(to: felt, token_id: Uint256):
    uint256_check(token_id)
    # Checks caller is not zero address
    let (caller) = get_caller_address()
    assert_not_zero(caller)

    # Ensures 'owner' does not equal 'to'
    let (owner) = ERC721_owners.read(token_id)
    assert_not_equal(owner, to)

    # Checks that either caller equals owner or
    # caller isApprovedForAll on behalf of owner
    if caller == owner:
        _approve(to, token_id)
        return ()
    else:
        let (is_approved) = ERC721_operator_approvals.read(owner, caller)
        assert_not_zero(is_approved)
        _approve(to, token_id)
        return ()
    end
end

func ERC721_setApprovalForAll{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(operator: felt, approved: felt):
    # Ensures caller is neither zero address nor operator
    let (caller) = get_caller_address()
    assert_not_zero(caller * operator)
    # note this pattern as we'll frequently use it:
    #   instead of making an `assert_not_zero` call for each address
    #   we can always briefly write `assert_not_zero(a0 * a1 * ... * aN)`.
    #   This is because these addresses are field elements,
    #   meaning that a*0==0 for all a in the field,
    #   and a*b==0 implies that at least one of a,b are zero in the field
    assert_not_equal(caller, operator)

    # Make sure `approved` is a boolean (0 or 1)
    assert approved * (1 - approved) = 0

    ERC721_operator_approvals.write(owner=caller, operator=operator, value=approved)
    return ()
end

func ERC721_transferFrom{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(_from: felt, to: felt, token_id: Uint256):
    alloc_locals
    uint256_check(token_id)
    let (caller) = get_caller_address()
    let (is_approved) = _is_approved_or_owner(caller, token_id)
    assert_not_zero(caller * is_approved)
    # Note that if either `is_approved` or `caller` equals `0`,
    # then this method should fail.
    # The `caller` address and `is_approved` boolean are both field elements
    # meaning that a*0==0 for all a in the field,
    # therefore a*b==0 implies that at least one of a,b is zero in the field

    _transfer(_from, to, token_id)
    return ()
end

func ERC721_safeTransferFrom{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(
        _from: felt,
        to: felt,
        token_id: Uint256,
        data_len: felt,
        data: felt*
    ):
    alloc_locals
    uint256_check(token_id)
    let (caller) = get_caller_address()
    let (is_approved) = _is_approved_or_owner(caller, token_id)
    assert_not_zero(caller * is_approved)
    # Note that if either `is_approved` or `caller` equals `0`,
    # then this method should fail.
    # The `caller` address and `is_approved` boolean are both field elements
    # meaning that a*0==0 for all a in the field,
    # therefore a*b==0 implies that at least one of a,b is zero in the field

    _safe_transfer(_from, to, token_id, data_len, data)
    return ()
end

func ERC721_mint{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(to: felt, token_id: Uint256):
    uint256_check(token_id)
    assert_not_zero(to)

    # Ensures token_id is unique
    let (exists) = _exists(token_id)
    assert exists = FALSE

    let (balance: Uint256) = ERC721_balances.read(to)
    let (new_balance: Uint256) = uint256_checked_add(balance, Uint256(1, 0))
    ERC721_balances.write(to, new_balance)
    ERC721_owners.write(token_id, to)
    return ()
end

func ERC721_burn{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(token_id: Uint256):
    alloc_locals
    uint256_check(token_id)
    let (local owner) = ERC721_ownerOf(token_id)

    # Clear approvals
    _approve(0, token_id)

    # Decrease owner balance
    let (balance: Uint256) = ERC721_balances.read(owner)
    let (new_balance: Uint256) = uint256_checked_sub_le(balance, Uint256(1, 0))
    ERC721_balances.write(owner, new_balance)

    # Delete owner
    ERC721_owners.write(token_id, 0)
    return ()
end

func ERC721_safeMint{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(
        to: felt,
        token_id: Uint256,
        data_len: felt,
        data: felt*
    ):
    uint256_check(token_id)
    ERC721_mint(to, token_id)

    let (success) = _check_onERC721Received(
        0,
        to,
        token_id,
        data_len,
        data
    )
    assert_not_zero(success)
    return ()
end

func ERC721_only_token_owner{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(token_id: Uint256):
    uint256_check(token_id)
    let (caller) = get_caller_address()
    let (owner) = ERC721_ownerOf(token_id)
    # Note `ERC721_ownerOf` checks that the owner is not the zero address
    assert caller = owner
    return ()
end

func ERC721_setTokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256, token_uri: felt):
    uint256_check(token_id)
    let (exists) = _exists(token_id)
    assert exists = TRUE

    ERC721_token_uri.write(token_id, token_uri)
    return ()
end

#
# Internals
#

func _approve{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, token_id: Uint256):
    ERC721_token_approvals.write(token_id, to)
    return ()
end

func _is_approved_or_owner{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    }(spender: felt, token_id: Uint256) -> (res: felt):
    alloc_locals

    let (exists) = _exists(token_id)
    assert exists = TRUE

    let (owner) = ERC721_ownerOf(token_id)
    if owner == spender:
        return (TRUE)
    end

    let (approved_addr) = ERC721_getApproved(token_id)
    if approved_addr == spender:
        return (TRUE)
    end

    let (is_operator) = ERC721_isApprovedForAll(owner, spender)
    if is_operator == TRUE:
        return (TRUE)
    end

    return (FALSE)
end

func _exists{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_id: Uint256) -> (res: felt):
    let (res) = ERC721_owners.read(token_id)

    if res == 0:
        return (FALSE)
    else:
        return (TRUE)
    end
end

func _transfer{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(_from: felt, to: felt, token_id: Uint256):
    # ownerOf ensures '_from' is not the zero address
    let (_ownerOf) = ERC721_ownerOf(token_id)
    assert _ownerOf = _from

    assert_not_zero(to)

    # Clear approvals
    _approve(0, token_id)

    # Decrease owner balance
    let (owner_bal) = ERC721_balances.read(_from)
    let (new_balance: Uint256) = uint256_checked_sub_le(owner_bal, Uint256(1, 0))
    ERC721_balances.write(_from, new_balance)

    # Increase receiver balance
    let (receiver_bal) = ERC721_balances.read(to)
    let (new_balance: Uint256) = uint256_checked_add(receiver_bal, Uint256(1, 0))
    ERC721_balances.write(to, new_balance)

    # Update token_id owner
    ERC721_owners.write(token_id, to)
    return ()
end

func _safe_transfer{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        _from: felt,
        to: felt,
        token_id: Uint256,
        data_len: felt,
        data: felt*
    ):
    _transfer(_from, to, token_id)

    let (success) = _check_onERC721Received(_from, to, token_id, data_len, data)
    assert_not_zero(success)
    return ()
end

func _check_onERC721Received{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        _from: felt,
        to: felt,
        token_id: Uint256,
        data_len: felt,
        data: felt*
    ) -> (success: felt):
    let (caller) = get_caller_address()
    # ERC721_RECEIVER_ID = 0x150b7a02
    let (is_supported) = IERC165.supportsInterface(to, 0x150b7a02)
    if is_supported == TRUE:
        let (selector) = IERC721_Receiver.onERC721Received(
            to,
            caller,
            _from,
            token_id,
            data_len,
            data
        )

        # ERC721_RECEIVER_ID
        assert selector = 0x150b7a02
        return (TRUE)
    end

    # IAccount_ID = 0x50b70dcb
    let (is_account) = IERC165.supportsInterface(to, 0x50b70dcb)
    return (is_account)
end
