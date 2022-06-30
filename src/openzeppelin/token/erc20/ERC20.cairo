# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (token/erc20/ERC20.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc20.library import ERC20

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        decimals: felt,
        initial_supply: Uint256,
        recipient: felt
    ):
    ERC20.initializer(name, symbol, decimals)
    ERC20._mint(recipient, initial_supply)
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
    }() -> (name: felt):
    let (name) = ERC20.name()
    return (name)
end

@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = ERC20.symbol()
    return (symbol)
end

@view
func totalSupply{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = ERC20.total_supply()
    return (totalSupply)
end

@view
func decimals{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let (decimals) = ERC20.decimals()
    return (decimals)
end

@view
func balanceOf{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = ERC20.balance_of(account)
    return (balance)
end

@view
func allowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256):
    let (remaining: Uint256) = ERC20.allowance(owner, spender)
    return (remaining)
end

#
# Externals
#

@external
func transfer{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    ERC20.transfer(recipient, amount)
    return (TRUE)
end

@external
func transferFrom{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        sender: felt,
        recipient: felt,
        amount: Uint256
    ) -> (success: felt):
    ERC20.transfer_from(sender, recipient, amount)
    return (TRUE)
end

@external
func approve{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256) -> (success: felt):
    ERC20.approve(spender, amount)
    return (TRUE)
end

@external
func increaseAllowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> (success: felt):
    ERC20.increase_allowance(spender, added_value)
    return (TRUE)
end

@external
func decreaseAllowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> (success: felt):
    ERC20.decrease_allowance(spender, subtracted_value)
    return (TRUE)
end
