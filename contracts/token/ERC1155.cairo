%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_nn_le, assert_not_equal, assert_not_zero
from starkware.cairo.common.alloc import alloc

#
# Storage
#

@storage_var
func balances(owner: felt, token_id: felt) -> (res: felt):
end

@storage_var
func operator_approvals(owner: felt, operator: felt) -> (res: felt):
end

@storage_var
func initialized() -> (res: felt):
end

# @storage_var
# func contract_uri() -> (res: felt):
# end

#Support interface !!
#
#
#


#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient: felt,
         token_id_len: felt,
          token_id: felt*,
           amount_len: felt,
            amount: felt*):
    # get_caller_address() returns '0' in the constructor;
    # therefore, recipient parameter is included
    _mint_batch(recipient, token_id_len, token_id, amount_len, amount)
    return ()
end


#
# Initializer
#

@external
func initialize_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        token_id_len: felt,
        token_id: felt*,
        amount_len: felt,
        amount: felt*):
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)

    let (sender) = get_caller_address()
    _mint_batch(sender, token_id_len, token_id, amount_len, amount)
    return ()
end

func _mint{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to: felt,
        token_id: felt,
        amount: felt) -> ():
    assert_not_zero(to)
    let (res) = balances.read(owner=to, token_id=token_id)
    balances.write(to, token_id, res + amount)
    return ()
end

func _mint_batch{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to: felt,
        token_id_len: felt,
        token_id: felt*,
        amount_len: felt,
        amount : felt*) -> ():
    assert_not_zero(to)
    assert token_id_len = amount_len

    if token_id_len == 0:
        return ()
    end
    _mint(to, token_id[0], amount[0])
    return _mint_batch(
        to=to,
        token_id_len=token_id_len - 1,
        token_id=token_id + 1,
        amount_len=amount_len - 1,
        amount=amount + 1)
end

#
# Getters
#

@view
func balance_of{pedersen_ptr: HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        owner: felt,
        token_id: felt) -> (res: felt):
    assert_not_zero(owner)
    let (res) = balances.read(owner=owner, token_id=token_id)
    return (res)
end

@view
func balance_of_batch{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        owner_len:felt,
        owner: felt*,
        token_id_len: felt,
        token_id: felt*) -> (res_len : felt, res : felt*):
    assert owner_len = token_id_len
    alloc_locals
    local max = owner_len
    let (local ret_array : felt*) = alloc()
    local ret_index = 0
    populate_balance_of_batch(owner, token_id, ret_array, ret_index, max)
    return (max, ret_array)
end

func populate_balance_of_batch{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    owner: felt*,
    token_id: felt*,
    rett: felt*,
    ret_index: felt,
    max: felt):
    alloc_locals
    if ret_index == max:
        return ()
    end
    let (local retval0 : felt) = balances.read(owner=owner[0], token_id=token_id[0])
    rett[0] = retval0
    populate_balance_of_batch(owner + 1, token_id + 1, rett + 1, ret_index + 1, max)
    return ()
end

#
# Approvals
#

@view
func is_approved_for_all{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr} (
        account: felt,
        operator: felt) -> (res: felt):
    let (res) = operator_approvals.read(owner=account, operator=operator)
    return (res=res)
end

@external
func set_approval_for_all{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr} (
    operator: felt,
    approved: felt):
    let (account) = get_caller_address()
    assert_not_equal(account, operator)
    operator_approvals.write(account, operator, approved)
    return()
end

#
# Transfer
#

@external
func transfer{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        recipient: felt,
        token_id: felt,
        amount: felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, token_id, amount)
    return ()
end

@external
func transfer_batch{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        recipient: felt,
        token_id_len: felt,
        token_id: felt*,
        amount_len: felt,
        amount: felt*):
    let (sender) = get_caller_address()
    assert token_id_len = amount_len
    if token_id_len == 0:
        return ()
    end
    _transfer(sender, recipient, token_id[0], amount[0])
    return transfer_batch(
        recipient=recipient,
        token_id_len=token_id_len - 1,
        token_id=token_id + 1,
        amount_len=amount_len - 1,
        amount=amount + 1)
end


# Transfer from
#

@external
func safe_transfert_from{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        _from: felt,
        to: felt,
        token_id: felt,
        token_no: felt):
    # alloc_locals
    # local pedersen_ptr2 : HashBuiltin* = pedersen_ptr
    # local syscall_ptr2 : felt* = syscall_ptr
    # local range_check_ptr2 = range_check_ptr
    let (_sender) = get_caller_address()
    if _from != _sender:
        let (_approved) = operator_approvals.read(owner=_from, operator=_sender)
        assert_not_zero(_approved)
        tempvar pedersen_ptr  = pedersen_ptr
        tempvar syscall_ptr  = syscall_ptr
        tempvar range_check_ptr = range_check_ptr 
    else:
        tempvar pedersen_ptr = pedersen_ptr
        tempvar syscall_ptr  = syscall_ptr
        tempvar range_check_ptr = range_check_ptr 
    end
    # local pedersen_ptr : HashBuiltin* = pedersen_ptr2
    # local syscall_ptr : felt* = syscall_ptr2
    # local range_check_ptr = range_check_ptr2
    _transfer(_from, to, token_id, token_no)
    return ()
end

@external
func safe_batch_transfert_from{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        _from: felt,
        to: felt,
        token_id_len: felt,
        token_id: felt*,
        amounts_len: felt,
        amounts: felt*):
        
    let (_sender) = get_caller_address()
    if _from != _sender:
        let (_approved) = operator_approvals.read(owner=_from, operator=_sender)
        assert_not_zero(_approved)
        tempvar pedersen_ptr  = pedersen_ptr
        tempvar syscall_ptr  = syscall_ptr
        tempvar range_check_ptr = range_check_ptr 
    else:
        tempvar pedersen_ptr = pedersen_ptr
        tempvar syscall_ptr  = syscall_ptr
        tempvar range_check_ptr = range_check_ptr 
    end
    _batch_transfer_from(_from, to, token_id_len, token_id, amounts_len, amounts)
    return()
end


func _batch_transfer_from{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    _from: felt,
    to: felt,
    token_id_len: felt,
    token_id: felt*,
    amounts_len: felt,
    amounts: felt*):
    if token_id_len == 0:
        return ()
    end
    # _transfer(_from, to, [token_id], [amounts])
    return _batch_transfer_from(
        _from=_from,
        to=to,
        token_id_len=token_id_len - 1,
        token_id=token_id + 1,
        amounts_len=amounts_len - 1,
        amounts=amounts + 1)
end

func _transfer{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        sender: felt,
        recipient: felt,
        token_id: felt,
        amount: felt):
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


###BURN

# func _burn{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
#     token_id: felt,
#     amount: felt):
#     assert_not_zero(_from)
#     asser
#     _transfer(
