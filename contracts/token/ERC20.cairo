%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_nn_le

@storage_var
func balances(user: felt) -> (res: felt):
end

@storage_var
func allowances(owner: felt, spender: felt) -> (res: felt):
end

@storage_var
func total_supply() -> (res: felt):
end

@view
func decimals() -> (res: felt):
    return (18)
end

@storage_var
func initialized() -> (res: felt):
end

@view
func get_total_supply{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } () -> (res: felt):
    let (res) = total_supply.read()
    return (res)
end

@view
func balanceOf{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (user: felt) -> (res: felt):
    let (res) = balances.read(user=user)
    return (res)
end

@view
func allowance{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (owner: felt, spender: felt) -> (res: felt):
    let (res) = allowances.read(owner=owner, spender=spender)
    return (res)
end

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

func _mint{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (recipient: felt, amount: felt):
    let (res) = balances.read(user=recipient)
    balances.write(recipient, res + amount)

    let (supply) = total_supply.read()
    total_supply.write(supply + amount)
    return ()
end

func _transfer{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (sender: felt, recipient: felt, amount: felt):
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
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (recipient: felt, amount: felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)
    return ()
end

@external
func transfer_from{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (sender: felt, recipient: felt, amount: felt):
    let (caller) = get_caller_address()
    let (caller_allowance) = allowances.read(owner=sender, spender=caller)
    assert_nn_le(amount, caller_allowance)
    _transfer(sender, recipient, amount)
    return ()
end

@external
func approve{
        storage_ptr: Storage*,
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (spender: felt, amount: felt):
    let (caller) = get_caller_address()
    allowances.write(owner=caller, spender=spender, amount=amount)
    return ()
end
