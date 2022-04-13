# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (token/erc20/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero, assert_lt
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import (
    Uint256, uint256_check
)

from openzeppelin.utils.constants import UINT8_MAX

from openzeppelin.security.safemath import (
    uint256_checked_add, uint256_checked_sub_le
)

#
# Events
#

@event
func Transfer(from_: felt, to: felt, value: Uint256):
end

@event
func Approval(owner: felt, spender: felt, value: Uint256):
end

#
# Storage
#

@storage_var
func ERC20_name_() -> (name: felt):
end

@storage_var
func ERC20_symbol_() -> (symbol: felt):
end

@storage_var
func ERC20_decimals_() -> (decimals: felt):
end

@storage_var
func ERC20_total_supply() -> (total_supply: Uint256):
end

@storage_var
func ERC20_balances(account: felt) -> (balance: Uint256):
end

@storage_var
func ERC20_allowances(owner: felt, spender: felt) -> (allowance: Uint256):
end

#
# Constructor
#

func ERC20_initializer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        decimals: felt
    ):
    ERC20_name_.write(name)
    ERC20_symbol_.write(symbol)
    with_attr error_message("ERC20: decimals exceed 2^8"):
        assert_lt(decimals, UINT8_MAX)
    end
    ERC20_decimals_.write(decimals)
    return ()
end

func ERC20_name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = ERC20_name_.read()
    return (name)
end

func ERC20_symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = ERC20_symbol_.read()
    return (symbol)
end

func ERC20_totalSupply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = ERC20_total_supply.read()
    return (totalSupply)
end

func ERC20_decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let (decimals) = ERC20_decimals_.read()
    return (decimals)
end

func ERC20_balanceOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = ERC20_balances.read(account)
    return (balance)
end

func ERC20_allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256):
    let (remaining: Uint256) = ERC20_allowances.read(owner, spender)
    return (remaining)
end

func ERC20_transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)
    return ()
end

func ERC20_transferFrom{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        sender: felt, 
        recipient: felt, 
        amount: Uint256
    ) -> ():
    alloc_locals
    let (caller) = get_caller_address()
    let (caller_allowance: Uint256) = ERC20_allowances.read(owner=sender, spender=caller)

    with_attr error_message("ERC20: transfer amount exceeds allowance"):
        let (new_allowance: Uint256) = uint256_checked_sub_le(caller_allowance, amount)
    end
    ERC20_allowances.write(sender, caller, new_allowance)

    _transfer(sender, recipient, amount)
    return ()
end

func ERC20_approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256):
    with_attr error_message("ERC20: amount is not a valid Uint256"):
        uint256_check(amount)
    end

    let (caller) = get_caller_address()
    with_attr error_message("ERC20: zero address cannot approve"):
        assert_not_zero(caller)
    end

    with_attr error_message("ERC20: cannot approve to the zero address"):
        assert_not_zero(spender)
    end

    ERC20_allowances.write(caller, spender, amount)
    Approval.emit(caller, spender, amount)
    return ()
end

func ERC20_increaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> ():
    with_attr error("ERC20: added_value is not a valid Uint256"):
        uint256_check(added_value)
    end

    let (caller) = get_caller_address()
    let (current_allowance: Uint256) = ERC20_allowances.read(caller, spender)

    # add allowance
    with_attr error_message("ERC20: allowance overflow"):
        let (new_allowance: Uint256) = uint256_checked_add(current_allowance, added_value)
    end

    ERC20_approve(spender, new_allowance)
    return ()
end

func ERC20_decreaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> ():
    alloc_locals
    with_attr error_message("ERC20: subtracted_value is not a valid Uint256"):
        uint256_check(subtracted_value)
    end

    let (caller) = get_caller_address()
    let (current_allowance: Uint256) = ERC20_allowances.read(owner=caller, spender=spender)

    with_attr error_message("ERC20: allowance below zero"):
        let (new_allowance: Uint256) = uint256_checked_sub_le(current_allowance, subtracted_value)
    end

    ERC20_approve(spender, new_allowance)
    return ()
end

func ERC20_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    with_attr error_message("ERC20: amount is not a valid Uint256"):
        uint256_check(amount)
    end

    with_attr error_message("ERC20: cannot mint to the zero address"):
        assert_not_zero(recipient)
    end

    let (supply: Uint256) = ERC20_total_supply.read()
    with_attr error_message("ERC20: mint overflow"):
        let (new_supply: Uint256) = uint256_checked_add(supply, amount)
    end
    ERC20_total_supply.write(new_supply)

    let (balance: Uint256) = ERC20_balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    let (new_balance: Uint256) = uint256_checked_add(balance, amount)
    ERC20_balances.write(recipient, new_balance)

    Transfer.emit(0, recipient, amount)
    return ()
end

func ERC20_burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt, amount: Uint256):
    alloc_locals
    with_attr error_message("ERC20: amount is not a valid Uint256"):
        uint256_check(amount)
    end

    with_attr error_message("ERC20: cannot burn from the zero address"):
        assert_not_zero(account)
    end

    let (balance: Uint256) = ERC20_balances.read(account)
    with_attr error_message("ERC20: burn amount exceeds balance"):
        let (new_balance: Uint256) = uint256_checked_sub_le(balance, amount)
    end
    ERC20_balances.write(account, new_balance)

    let (supply: Uint256) = ERC20_total_supply.read()
    let (new_supply: Uint256) = uint256_checked_sub_le(supply, amount)
    ERC20_total_supply.write(new_supply)
    Transfer.emit(account, 0, amount)
    return ()
end

#
# Internal
#

func _transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: Uint256):
    alloc_locals
    with_attr error_message("ERC20: amount is not a valid Uint256"):
        uint256_check(amount) # almost surely not needed, might remove after confirmation
    end

    with_attr error_message("ERC20: cannot transfer from the zero address"):
        assert_not_zero(sender)
    end

    with_attr error_message("ERC20: cannot transfer to the zero address"):
        assert_not_zero(recipient)
    end

    let (sender_balance: Uint256) = ERC20_balances.read(account=sender)
    with_attr error_message("ERC20: transfer amount exceeds balance"):
        let (new_sender_balance: Uint256) = uint256_checked_sub_le(sender_balance, amount)
    end
    ERC20_balances.write(sender, new_sender_balance)

    # add to recipient
    let (recipient_balance: Uint256) = ERC20_balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance: Uint256) = uint256_checked_add(recipient_balance, amount)
    ERC20_balances.write(recipient, new_recipient_balance)
    Transfer.emit(sender, recipient, amount)
    return ()
end
