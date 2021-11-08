%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_nn_le

@storage_var
func owner(token_id: felt, token_no: felt) -> (res: felt):
end

@storage_var
func balance(owner: felt, token_id: felt) -> (res: felt):
end

@storage_var
func token_approvals(token_id: felt, token_no: felt) -> (res: felt):
end

@storage_var
func operator_approvals(owner: felt, operator: felt) -> (res: felt):
end
################ Now it's felt* maybe after string will be implemented on cairo
@storage_var
func contract_uri() -> (res: felt*):
end

@storage_var
func  max_token_id(token_id: felt) ->  (res: felt):
end

#Support interface !!
#
#
#
@view

#### fonction uri --> after !!!!
@external
func initialize{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } ():
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)

    let (sender) = get_caller_address()
    _mint(sender, 1000)
    return ()
end

@view
func balance_of{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (owner: felt, token_id: felt) -> (res: felt):
    let (res) = balance.read(owner=owner, token_id=id)
    return (res)
end

@view
func balance_of_batch{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (owner: felt) -> (res: felt):
    ###Have to make a sum
    let (res) = balances_sum(balance.read(owner=owner, id=max_token_id.read()), size=max_token_id.read())
    return (res)
end

@view
func owner_of{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (token_id: felt, token_no: felt) -> (res: felt):
    let (res) = owner.read(token_id=token_id, token_no=token_no)
    return (res)
end


@external
func set_approval_for_all{
    storage_ptr: Storage*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
    } (operator: felt, approved: felt):
    _set_approval_for_all(account=get_caller_address(),operator, approved)
    return ()
end


@view
func is_approved_for_all{
    storage_ptr: Storage*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
    } (account: felt, operator: felt) -> (res: felt):
    let (res) = operator_approvals(owner=account, operator).read(res)
    return (res)
end

func _set_approval_for_all{
    storage_ptr: Storage*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
    } (account: felt, operator: felt, approved: felt):
    if account == operator:
        return()
    end
    operator_approvals(owner=account, operator).write(approved) 
    return ()
end


func balances_sum(balance_of_one : felt, size : felt) -> (total_balance : felt):
    if size == 0:
        return(total_balance=0)
    end
    let (sum_of_rest) = balances_sum(balance_of_one=balance.read(owner=owner, id=size -1), size=size - 1)
    return (total_balance= balance_of_one + sum_of_rest)
end
