%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt
)

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
func balances(account: felt) -> (res: Uint256):
end

@storage_var
func allowances(owner: felt, spender: felt) -> (res: Uint256):
end

@storage_var
func total_supply() -> (res: Uint256):
end

@storage_var
func decimals() -> (res: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        recipient: felt
    ):
    # get_caller_address() returns '0' in the constructor;
    # therefore, recipient parameter is included
    _name.write(name)
    _symbol.write(symbol)
    decimals.write(18)
    _mint(recipient, Uint256(1000, 0))
    return ()
end

#
# Getters
#

@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = _name.read()
    return (res)
end

@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = _symbol.read()
    return (res)
end

@view
func get_total_supply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: Uint256):
    let (res: Uint256) = total_supply.read()
    return (res)
end

@view
func get_decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = decimals.read()
    return (res)
end

@view
func balance_of{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (res: Uint256):
    let (res: Uint256) = balances.read(account=account)
    return (res)
end

@view
func allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (res: Uint256):
    let (res: Uint256) = allowances.read(owner=owner, spender=spender)
    return (res)
end

#
# Internals
#

func _mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(recipient)

    let (balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    let (new_balance, _: Uint256) = uint256_add(balance, amount)
    balances.write(recipient, new_balance)

    let (local supply: Uint256) = total_supply.read()
    let (local new_supply: Uint256, is_overflow) = uint256_add(supply, amount)
    assert (is_overflow) = 0

    total_supply.write(new_supply)
    return ()
end

func _transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(sender)
    assert_not_zero(recipient)

    let (local sender_balance: Uint256) = balances.read(account=sender)

    # validates amount <= sender_balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, sender_balance)
    assert_not_zero(enough_balance)

    # subtract from sender
    let (new_sender_balance: Uint256) = uint256_sub(sender_balance, amount)
    balances.write(sender, new_sender_balance)

    # add to recipient
    let (recipient_balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance, _: Uint256) = uint256_add(recipient_balance, amount)
    balances.write(recipient, new_recipient_balance)
    return ()
end

func _approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(caller: felt, spender: felt, amount: Uint256):
    assert_not_zero(caller)
    assert_not_zero(spender)
    allowances.write(caller, spender, amount)
    return ()
end

func _burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(account)

    let (balance: Uint256) = balances.read(account)
    # validates amount <= balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, balance)
    assert_not_zero(enough_balance)
    
    let (new_balance: Uint256) = uint256_sub(balance, amount)
    balances.write(account, new_balance)

    let (supply: Uint256) = total_supply.read()
    let (new_supply: Uint256) = uint256_sub(supply, amount)
    total_supply.write(new_supply)
    return ()
end

#
# Externals
#

@external
func transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)
    return ()
end

@external
func transfer_from{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: Uint256):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local caller_allowance: Uint256) = allowances.read(owner=sender, spender=caller)

    # validates amount <= caller_allowance and returns 1 if true   
    let (enough_balance) = uint256_le(amount, caller_allowance)
    assert_not_zero(enough_balance)

    _transfer(sender, recipient, amount)

    # subtract allowance
    let (new_allowance: Uint256) = uint256_sub(caller_allowance, amount)
    allowances.write(sender, caller, new_allowance)
    return ()
end

@external
func approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256):
    let (caller) = get_caller_address()
    _approve(caller, spender, amount)
    return ()
end

@external
func increase_allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local current_allowance: Uint256) = allowances.read(caller, spender)

    # add allowance
    let (local new_allowance: Uint256, is_overflow) = uint256_add(current_allowance, added_value)
    assert (is_overflow) = 0

    _approve(caller, spender, new_allowance)
    return()
end

@external
func decrease_allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local current_allowance: Uint256) = allowances.read(owner=caller, spender=spender)
    let (local new_allowance: Uint256) = uint256_sub(current_allowance, subtracted_value)

    # validates new_allowance < current_allowance and returns 1 if true   
    let (enough_allowance) = uint256_lt(new_allowance, current_allowance)
    assert_not_zero(enough_allowance)

    _approve(caller, spender, new_allowance)
    return()
end

#
# Test functions — will remove once extensibility is resolved
#

@external
func mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    _mint(recipient, amount)
    return()
end

@external
func burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(user: felt, amount: Uint256):
    _burn(user, amount)
    return()
end
