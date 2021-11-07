%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_nn_le

@storage_var
func owner(token_id: felt) -> (res: felt):
end

@storage_var
func balances(owner: felt) -> (res: felt):
end

@storage_var
func token_approvals(token_id: felt) -> (res: felt):
end

@storage_var
func operator_approvals(owner: felt, operator: felt) -> (res: felt):
end

@storage_var
func initialized() -> (res: felt):
end

@constsructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt):
    let (recipient) = get_caller_address()
    _mint(recipient, 1000)
    return()
end

@external
func initialize{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)
    return ()
end

@view
func balance_of{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt) -> (res: felt):
    let (res) = balances.read(owner=owner)
    return (res)
end

@view
func owner_of{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token_id: felt) -> (res: felt):
    let (res) = owner.read(token_id=token_id)
    return (res)
end

@external
func approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(to: felt, token_id: felt):
    let (_owner) = owner.read(token_id)

    if _owner == to:
        assert 1 = 0
    end

    _is_approved_or_owner()
    token_approvals.write(token_id=token_id, to)
    return ()
end

func _is_approved_or_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(to: felt, token_id: felt):
    let (caller) = get_caller_address()
    let (_owner) = owner.read(token_id)

    if caller == _owner:
        return ()
    end

    let (res) = token_approvals(token_id)
    assert res = caller
end

@view
func get_approved{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token_id: felt) -> (res: felt):
    let (res) = token_approvals.read(token_id=token_id)
    return (res)
end

func _mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: felt):
    let (res) = balances.read(user=recipient)
    balances.write(recipient, res + amount)

    let (supply) = total_supply.read()
    total_supply.write(supply + amount)
    return ()
end

func _transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: felt):
    # validate sender has enough funds
    let (sender_balance) = balances.read(user=sender)
    assert_nn_le(amount, sender_balance)

    # substract from sender
    balances.write(sender, sender_balance - amount)

    # add to recipient
    let (res) = balances.read(user=recipient)
    balances.write(recipient, res + amount)
    return ()
end

@external
func transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)
    return ()
end

@external
func transfer_from{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: felt):
    let (caller) = get_caller_address()
    let (caller_allowance) = allowances.read(owner=sender, spender=caller)
    assert_nn_le(amount, caller_allowance)
    _transfer(sender, recipient, amount)
    allowances.write(sender, caller, caller_allowance - amount)
    return ()
end
