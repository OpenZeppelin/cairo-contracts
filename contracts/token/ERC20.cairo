%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_nn_le

#
# Storage
#

@storage_var
func balances(user: felt) -> (res: felt):
end

@storage_var
func allowances(owner: felt, spender: felt) -> (res: felt):
end

@storage_var
func total_supply() -> (res: felt):
end

@storage_var
func decimals() -> (res: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(deployer: felt):
    decimals.write(18)
    _mint(deployer, 1000)
    return ()
end

#
# Getters
#

@view
func get_total_supply{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} () -> (res: felt):
    let (res) = total_supply.read()
    return (res)
end

@view
func get_decimals{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} () -> (res: felt):
    let (res) = decimals.read()
    return (res)
end

@view
func balance_of{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} (user: felt) -> (res: felt):
    let (res) = balances.read(user=user)
    return (res)
end

@view
func allowance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} (owner: felt, spender: felt) -> (res: felt):
    let (res) = allowances.read(owner=owner, spender=spender)
    return (res)
end

#
# Internals
#

func _mint{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} (recipient: felt, amount: felt):
    let (res) = balances.read(user=recipient)
    balances.write(recipient, res + amount)

    let (supply) = total_supply.read()
    total_supply.write(supply + amount)
    return ()
end

func _transfer{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(sender: felt, recipient: felt, amount: felt):
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

func _approve{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(caller: felt, spender: felt, amount: felt):
    allowances.write(caller, spender, amount)
    return ()
end

#
# Externals
#

@external
func transfer{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(recipient: felt, amount: felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)
    return ()
end

@external
func transfer_from{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(sender: felt, recipient: felt, amount: felt):
    let (caller) = get_caller_address()
    let (caller_allowance) = allowances.read(owner=sender, spender=caller)
    assert_nn_le(amount, caller_allowance)
    _transfer(sender, recipient, amount)
    allowances.write(sender, caller, caller_allowance - amount)
    return ()
end

@external
func approve{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(spender: felt, amount: felt):
    let (caller) = get_caller_address()
    _approve(caller, spender, amount)
    return ()
end

@external
func increase_allowance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(spender: felt, added_value: felt):
    let (caller) = get_caller_address()
    let (current_allowance) = allowances.read(caller, spender)
    # using a tempvar for internal check
    tempvar res = current_allowance + added_value
    # overflow check
    assert_nn_le(current_allowance + added_value, res)
    _approve(caller, spender, res)
    return()
end

@external
func decrease_allowance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} (spender: felt, subtracted_value: felt):
    let (caller) = get_caller_address()
    let (current_allowance) = allowances.read(owner=caller, spender=spender)
    # checks that the decreased balance isn't below zero
    assert_nn_le(subtracted_value, current_allowance)
    _approve(caller, spender, current_allowance - subtracted_value)
    return()
end

