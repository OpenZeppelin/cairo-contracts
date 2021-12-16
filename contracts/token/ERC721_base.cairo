%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub
)

from contracts.ERC165 import (
    ERC165_supportsInterface
)

#
# Receiver Interface
#

@contract_interface
namespace IERC721_Receiver:
    func onERC721Received(
        operator: felt,
        _from: felt,
        token_id: Uint256,
        data: felt
    ) -> (ret_val: felt):
    end
end

#
# Storage
#

@storage_var
func ERC721_name() -> (name: felt):
end

@storage_var
func ERC721_symbol() -> (symbol: felt):
end

@storage_var
func ERC721_owners(token_id_low: felt, token_id_high: felt) -> (owner: felt):
end

@storage_var
func ERC721_balances(account: felt) -> (balance: Uint256):
end

@storage_var
func ERC721_token_approvals(token_id_low: felt, token_id_high: felt) -> (res: felt):
end

@storage_var
func ERC721_operator_approvals(owner: felt, operator: felt) -> (res: felt):
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
    ERC721_name.write(name)
    ERC721_symbol.write(symbol)
    return ()
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
    if interface_id == '0x80ac58cd':
        return (1)
    end

    # 165
    let (is_165) = ERC165_supportsInterface(interface_id)
    if is_165 == 1:
        return (1)
    end
    return (0)
end

@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = ERC721_name.read()
    return (name)
end

@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = ERC721_symbol.read()
    return (symbol)
end

@view
func balanceOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = ERC721_balances.read(account=account)
    return (balance)
end

@view
func ownerOf{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token_id: Uint256) -> (owner: felt):
    let (owner) = ERC721_owners.read(token_id.low, token_id.high)
    # Ensuring the query is not for nonexistent token
    assert_not_zero(owner)
    return (owner)
end

@view
func getApproved{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token_id: Uint256) -> (approved: felt):
    let (exists) = _exists(token_id)
    assert exists = 1

    let (approved) = ERC721_token_approvals.read(token_id.low, token_id.high)
    return (approved)
end

@view
func isApprovedForAll{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(owner: felt, operator: felt) -> (is_approved: felt):
    let (is_approved) = ERC721_operator_approvals.read(owner=owner, operator=operator)
    return (is_approved)
end

#
# Externals
#

func ERC721_approve{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    # Checks caller is not zero address
    let (caller) = get_caller_address()
    assert_not_zero(caller)

    # Ensures 'owner' does not equal 'to'
    let (owner) = ERC721_owners.read(token_id.low, token_id.high)
    assert_not_equal(owner, to)

    # Checks that either caller equals owner or
    # caller isApprovedForAll on behalf of owner
    if caller == owner:
        _approve(to, token_id)
        return()
    else:
        let (is_approved) = ERC721_operator_approvals.read(owner, caller)
        assert_not_zero(is_approved)
        _approve(to, token_id)
        return()
    end
end

func ERC721_set_approval_for_all{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(operator: felt, approved: felt):
    # Ensures caller is neither zero address nor operator
    let (caller) = get_caller_address()
    assert_not_zero(caller)
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
    let (caller) = get_caller_address()
    _is_approved_or_owner(caller, token_id)
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
        data: felt
    ):
    let (caller) = get_caller_address()
    _is_approved_or_owner(caller, token_id)
    _safe_transfer(_from, to, token_id, data)
    return ()
end

func ERC721_mint{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    assert_not_zero(to)

    # Ensures token_id is unique
    let (exists) = _exists(token_id)
    assert exists = 0

    let (balance: Uint256) = ERC721_balances.read(to)
    # Overflow is not possible because token_ids are checked for duplicate ids with `_exists()`
    # thus, each token is guaranteed to be a unique uint256
    let (new_balance: Uint256, _) = uint256_add(balance, Uint256(1, 0))
    ERC721_balances.write(to, new_balance)

    # low + high felts = uint256
    ERC721_owners.write(token_id.low, token_id.high, to)
    return ()
end

func ERC721_burn{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(token_id: Uint256):
    alloc_locals
    let (local owner) = ownerOf(token_id)

    # Clear approvals
    _approve(0, token_id)

    # Decrease owner balance
    let (balance: Uint256) = ERC721_balances.read(owner)
    let (new_balance) = uint256_sub(balance, Uint256(1, 0))
    ERC721_balances.write(owner, new_balance)

    # Delete owner
    ERC721_owners.write(token_id.low, token_id.high, 0)
    return ()
end

func ERC721_safe_mint{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256, data: felt):
    ERC721_mint(to, token_id)
    let (success) = _check_onERC721Received(
        0,
        to,
        token_id,
        data
    )
    assert_not_zero(success)
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
    ERC721_token_approvals.write(token_id.low, token_id.high, to)
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
    let (res) = ERC721_owners.read(token_id.low, token_id.high)

    if res == 0:
        return (0)
    else:
        return (1)
    end
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
    let (owner_bal) = ERC721_balances.read(_from)
    let (new_balance) = uint256_sub(owner_bal, Uint256(1, 0))
    ERC721_balances.write(_from, new_balance)

    # Increase receiver balance
    let (receiver_bal) = ERC721_balances.read(to)
    # overflow not possible because token_id must be unique
    let (new_balance: Uint256, _) = uint256_add(receiver_bal, Uint256(1, 0))
    ERC721_balances.write(to, new_balance)

    # Update token_id owner
    ERC721_owners.write(token_id.low, token_id.high, to)
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
    let (ret_val) = IERC721_Receiver.onERC721Received(
        to, 
        caller, 
        _from, 
        token_id, 
        data
    )

    # ERC721_RECEIVER_ID
    assert (ret_val) = '0x150b7a02'

    # Cairo equivalent to 'return (true)'
    return (1)
end