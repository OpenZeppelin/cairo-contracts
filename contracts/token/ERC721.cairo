%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_equal, assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt
)

#
# Receiver Interface
#

@contract_interface
namespace IERC721Receiver:
    func onERC721Received(
        operator: felt,
        _from: felt,
        token_id: Uint256,
        data: felt
    ) -> (ret_val: felt):
    end
end

#
# InterfaceIds
#

const ERC165_ID = '0x01ffc9a7'
const ERC721_RECEIVER_ID = '0x150b7a02'
const ERC721_ID = '0x80ac58cd'
const INVALID_ID = '0xffffffff'

#
# Storage
#

@storage_var
func _name() -> (res: felt):
end

@storage_var
func _symbol() -> (res: felt):
end

@storage_var
func owners(token_id_low: felt, token_id_high: felt) -> (res: felt):
end

@storage_var
func balances(owner: felt) -> (res: Uint256):
end

@storage_var
func token_approvals(token_id_low: felt, token_id_high: felt) -> (res: felt):
end

@storage_var
func operator_approvals(owner: felt, operator: felt) -> (res: felt):
end

@storage_var
func base_uri() -> (res: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(name: felt, symbol: felt, _base_uri: felt, owner: felt,):
    _name.write(name)
    _symbol.write(symbol)
    base_uri.write(_base_uri)

    # Setting contract owner for testing
    contract_owner.write(owner)
    return()
end

#
# Getters
#

@view
func supportsInterface{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (interface_id: felt) -> (success: felt):
    # 721
    if interface_id == ERC721_ID:
        return (1)
    end

    # 165
    if interface_id == ERC165_ID:
        return (1)
    end

    # The INVALID_ID must explicitly return false ('0')
    # according to EIP721
    if interface_id == INVALID_ID:
        return (0)
    end

    return (0)
end

@view
func balanceOf{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(owner: felt) -> (balance: Uint256):
    # Checks that query is not for zero address
    assert_not_zero(owner)

    let (balance: Uint256) = balances.read(owner=owner)
    return (balance)
end

@view
func ownerOf{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token_id: Uint256) -> (owner: felt):
    let (owner) = owners.read(token_id.low, token_id.high)
    # Ensuring the query is not for nonexistent token
    assert_not_zero(owner)

    return (owner)
end

@view
func name{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (name: felt):
    let (name) = _name.read()
    return (name)
end

@view
func symbol{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = _symbol.read()
    return (symbol)
end

@view
func getApproved{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token_id: Uint256) -> (approved: felt):
    let (exists) = _exists(token_id)
    assert exists = 1

    let (approved) = token_approvals.read(token_id.low, token_id.high)
    return (approved)
end

@view
func isApprovedForAll{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(owner: felt, operator: felt) -> (is_approved: felt):
    let (is_approved) = operator_approvals.read(owner=owner, operator=operator)
    return (is_approved)
end

@view
func tokenURI{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token_id: Uint256) -> (uri_len: felt, uri: felt*):
    alloc_locals
    let (exists) = _exists(token_id)
    assert exists = 1

    let (local base) = base_uri.read()
    let (local uri) = alloc()
    # without baseURI
    if base == 0:
        assert [uri] = token_id.low
        assert [uri + 1] = token_id.high
        return (2, uri)
    end
    
    # with baseURI
    assert [uri] = base
    assert [uri + 1] = token_id.low
    assert [uri + 2] = token_id.high
    return (3, uri)
end

#
# Externals
#

@external
func approve{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(approved: felt, token_id: Uint256):
    # Checks caller is not zero address
    let (caller) = get_caller_address()
    assert_not_zero(caller)

    # Ensures 'owner' does not equal 'to'
    let (owner) = owners.read(token_id.low, token_id.high)
    assert_not_equal(owner, approved)

    # Checks that either caller equals owner or
    # caller isApprovedForAll on behalf of owner
    if caller == owner:
        _approve(approved, token_id)
        return()
    else:
        let (is_approved) = isApprovedForAll(owner, caller)
        assert_not_zero(is_approved)
        _approve(approved, token_id)
        return()
    end
end

@external
func setApprovalForAll{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(operator: felt, approved: felt):
    let (caller) = get_caller_address()

    _set_approval_for_all(caller, operator, approved)
    return ()
end

@external
func transferFrom{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(_from: felt, to: felt, token_id: Uint256):
    let (caller) = get_caller_address()
    _is_approved_or_owner(caller, token_id)

    _transfer(_from, to, token_id)
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
    let (caller) = get_caller_address()
    _is_approved_or_owner(caller, token_id)

    _safe_transfer(_from, to, token_id, data)
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
    token_approvals.write(token_id.low, token_id.high, to)
    return ()
end

func _is_approved_or_owner{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(spender: felt, token_id: Uint256) -> (res: felt):
    alloc_locals

    let (exists) = _exists(token_id)
    assert exists = 1

    let (owner) = ownerOf(token_id)
    if owner == spender:
        return (1)
    end

    let (approved_addr) = getApproved(token_id)
    if approved_addr == spender:
        return (1)
    end

    let (is_operator) = isApprovedForAll(owner, spender)
    if is_operator == 1:
        return (1)
    end

    return (0)
end

func _exists{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token_id: Uint256) -> (res: felt):
    let (res) = owners.read(token_id.low, token_id.high)

    if res == 0:
        return (0)
    else:
        return (1)
    end
end

func _mint{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    assert_not_zero(to)

    # Ensures token_id is unique
    let (exists) = _exists(token_id)
    assert exists = 0

    let (balance: Uint256) = balances.read(to)
    # Overflow is not possible because token_ids are checked for duplicate ids with `_exists()`
    # thus, each token is guaranteed to be a unique uint256
    let (new_balance: Uint256, _) = uint256_add(balance, Uint256(1, 0))
    balances.write(to, new_balance)

    # low + high felts = uint256
    owners.write(token_id.low, token_id.high, to)
    return ()
end

func _burn{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(token_id: Uint256):
    let (owner) = ownerOf(token_id)

    # Clear approvals
    _approve(0, token_id)

    # Decrease owner balance
    let (balance: Uint256) = balances.read(owner)
    let (new_balance) = uint256_sub(balance, Uint256(1, 0))
    balances.write(owner, new_balance)

    # Delete owner
    owners.write(token_id.low, token_id.high, 0)
    return ()
end

func _transfer{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(_from: felt, to: felt, token_id: Uint256):
    # ownerOf ensures '_from' is not the zero address
    let (_ownerOf) = ownerOf(token_id)
    assert _ownerOf = _from

    assert_not_zero(to)

    # Clear approvals
    _approve(0, token_id)

    # Decrease owner balance
    let (owner_bal) = balances.read(_from)
    let (new_balance) = uint256_sub(owner_bal, Uint256(1, 0))
    balances.write(_from, new_balance)

    # Increase receiver balance
    let (receiver_bal) = balances.read(to)
    # overflow not possible because token_id must be unique
    let (new_balance: Uint256, _) = uint256_add(receiver_bal, Uint256(1, 0))
    balances.write(to, new_balance)

    # Update token_id owner
    owners.write(token_id.low, token_id.high, to)
    return ()
end

func _set_approval_for_all{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(owner: felt, operator: felt, approved: felt):
    assert_not_equal(owner, operator)

    # Make sure `approved` is a boolean (0 or 1)
    assert approved * (1 - approved) = 0

    operator_approvals.write(owner=owner, operator=operator, value=approved)
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
        data: felt
    ):
    _transfer(_from, to, token_id)

    let (success) = _check_onERC721Received(_from, to, token_id, data)
    assert_not_zero(success)
    return ()
end

func _base_uri{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (res: felt):
    let (res) = base_uri.read()
    return (res)
end

func _check_onERC721Received{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _from: felt, 
        to: felt, 
        token_id: Uint256,
        data: felt
    ) -> (success: felt):
    # We need to consider how to differentiate between EOA and contracts
    # and insert a conditional to know when to use the proceeding check
    let (caller) = get_caller_address()
    # The first parameter in an imported interface is the contract
    # address of the interface being called
    let (ret_val) = IERC721Receiver.onERC721Received(
        to, 
        caller, 
        _from, 
        token_id, 
        data
    )

    assert (ret_val) = ERC721_RECEIVER_ID
    # Cairo equivalent to 'return (true)'
    return (1)
end

#
# Exposed methods with _only_owner() assertion for testing
#

@storage_var
func contract_owner() -> (res: felt):
end

func _only_owner{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(account: felt):
    let (owner) = contract_owner.read()
    assert account = owner
    return ()
end

@external
func mint{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    let (caller) = get_caller_address()
    _only_owner(caller)

    _mint(to, token_id)
    return ()
end

@external
func burn{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(token_id: Uint256):
    alloc_locals
    let (local caller) = get_caller_address()
    _only_owner(caller)
    # Contract owner can only burn their own tokens
    # for testing and safety in production
    let (token_owner) = ownerOf(token_id)
    assert caller = token_owner

    _burn(token_id)
    return ()
end

