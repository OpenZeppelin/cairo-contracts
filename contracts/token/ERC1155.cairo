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
func balances(owner : felt, token_id : felt) -> (res : felt):
end

@storage_var
func operator_approvals(owner : felt, operator : felt) -> (res : felt):
end

@storage_var
func initialized() -> (res : felt):
end

# @storage_var
# func contract_uri() -> (res: felt):
# end

# Support interface !!
#
#
#

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, tokens_id_len : felt, tokens_id : felt*, amounts_len : felt,
        amounts : felt*):
    # get_caller_address() returns '0' in the constructor;
    # therefore, recipient parameter is included
    _mint_batch(recipient, tokens_id_len, tokens_id, amounts_len, amounts)
    return ()
end

#
# Initializer
#

@external
func initialize_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        tokens_id_len : felt, tokens_id : felt*, amounts_len : felt, amounts : felt*):
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)
    let (sender) = get_caller_address()
    _mint_batch(sender, tokens_id_len, tokens_id, amounts_len, amounts)
    return ()
end

func _mint{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to : felt, token_id : felt, amount : felt) -> ():
    assert_not_zero(to)
    let (res) = balances.read(owner=to, token_id=token_id)
    balances.write(to, token_id, res + amount)
    return ()
end

func _mint_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to : felt, tokens_id_len : felt, tokens_id : felt*, amounts_len : felt,
        amounts : felt*) -> ():
    assert_not_zero(to)
    assert tokens_id_len = amounts_len

    if tokens_id_len == 0:
        return ()
    end
    _mint(to, tokens_id[0], amounts[0])
    return _mint_batch(
        to=to,
        tokens_id_len=tokens_id_len - 1,
        tokens_id=tokens_id + 1,
        amounts_len=amounts_len - 1,
        amounts=amounts + 1)
end

#
# Getters
#

@view
func balance_of{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owner : felt, token_id : felt) -> (res : felt):
    assert_not_zero(owner)
    let (res) = balances.read(owner=owner, token_id=token_id)
    return (res)
end

@view
func balance_of_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owners_len : felt, owners : felt*, tokens_id_len : felt, tokens_id : felt*) -> (
        res_len : felt, res : felt*):
    assert owners_len = tokens_id_len
    alloc_locals
    local max = owners_len
    let (local ret_array : felt*) = alloc()
    local ret_index = 0
    populate_balance_of_batch(owners, tokens_id, ret_array, ret_index, max)
    return (max, ret_array)
end

func populate_balance_of_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owners : felt*, tokens_id : felt*, rett : felt*, ret_index : felt, max : felt):
    alloc_locals
    if ret_index == max:
        return ()
    end
    let (local retval0 : felt) = balances.read(owner=owners[0], token_id=tokens_id[0])
    rett[0] = retval0
    populate_balance_of_batch(owners + 1, tokens_id + 1, rett + 1, ret_index + 1, max)
    return ()
end

#
# Approvals
#

@view
func is_approved_for_all{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        account : felt, operator : felt) -> (res : felt):
    let (res) = operator_approvals.read(owner=account, operator=operator)
    return (res=res)
end

@external
func set_approval_for_all{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        operator : felt, approved : felt):
    let (account) = get_caller_address()
    assert_not_equal(account, operator)
    operator_approvals.write(account, operator, approved)
    return ()
end

#
# Transfer from
#

@external
func safe_transfer_from{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, to : felt, token_id : felt, amount : felt):
    # let (_sender) = get_caller_address()
    # if _from != _sender:
    #     let (_approved) = is_approved_for_all(account=_from, operator=_sender)
    #     assert_not_zero(_approved)
    #     tempvar pedersen_ptr = pedersen_ptr
    #     tempvar syscall_ptr = syscall_ptr
    #     tempvar range_check_ptr = range_check_ptr
    # else:
    #     tempvar pedersen_ptr = pedersen_ptr
    #     tempvar syscall_ptr = syscall_ptr
    #     tempvar range_check_ptr = range_check_ptr
    # end
    _is_owner_or_approved_operator(_from)
    _transfer_from(_from, to, token_id, amount)
    return ()
end

@external
func safe_batch_transfer_from{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, to : felt, tokens_id_len : felt, tokens_id : felt*, amounts_len : felt,
        amounts : felt*):
    # let (_sender) = get_caller_address()
    # if _from != _sender:
    #     let (_approved) = is_approved_for_all(account=_from, operator=_sender)
    #     assert_not_zero(_approved)
    #     tempvar pedersen_ptr = pedersen_ptr
    #     tempvar syscall_ptr = syscall_ptr
    #     tempvar range_check_ptr = range_check_ptr
    # else:
    #     tempvar pedersen_ptr = pedersen_ptr
    #     tempvar syscall_ptr = syscall_ptr
    #     tempvar range_check_ptr = range_check_ptr
    # end
    _is_owner_or_approved_operator(_from)
    _batch_transfer_from(_from, to, tokens_id_len, tokens_id, amounts_len, amounts)
    return ()
end

func _transfer_from{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
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

func _batch_transfer_from{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, to : felt, tokens_id_len : felt, tokens_id : felt*, amounts_len : felt,
        amounts : felt*):
    assert tokens_id_len = amounts_len
    assert_not_zero(to)

    if tokens_id_len == 0:
        return ()
    end
    _transfer_from(_from, to, [tokens_id], [amounts])
    return _batch_transfer_from(
        _from=_from,
        to=to,
        tokens_id_len=tokens_id_len - 1,
        tokens_id=tokens_id + 1,
        amounts_len=amounts_len - 1,
        amounts=amounts + 1)
end

# function to test ERC1155 requirement : require(from == _msgSender() || isApprovedForAll(from, _msgSender())
func _is_owner_or_approved_operator{
        pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(address : felt) -> (
        res : felt):
    let (caller) = get_caller_address()

    if caller == address:
        return (1)
    end

    let (operator_is_approved) = is_approved_for_all(account=address, operator=caller)
    assert operator_is_approved = 1
    return (operator_is_approved)
end

#
# Burn
#

func _burn{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, token_id : felt, amount : felt):
    assert_not_zero(_from)

    let (from_balance) = balance_of(_from, token_id)
    assert_le(amount, from_balance)
    balances.write(_from, token_id, from_balance - amount)
    return ()
end

func _burn_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, tokens_id_len : felt, tokens_id : felt*, amounts_len : felt, amounts : felt*):
    assert_not_zero(_from)

    assert tokens_id_len = amounts_len
    if tokens_id_len == 0:
        return ()
    end
    let (from_balance) = balance_of(_from, [tokens_id])
    assert_le([amounts], from_balance)
    balances.write(_from, [tokens_id], from_balance - [amounts])
    return _burn_batch(
        _from=_from,
        tokens_id_len=tokens_id_len - 1,
        tokens_id=tokens_id + 1,
        amounts_len=amounts_len - 1,
        amounts=amounts + 1)
end
