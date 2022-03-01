# SPDX-License-Identifier: MIT

%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.upgrades.library import (
    Proxy_initializer,
    Proxy_get_implementation
)

#
# Storage
#

@storage_var
func value() -> (res: felt):
end

#
# Initializer
#

@external
func initializer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(proxy_admin: felt):
    Proxy_initializer(proxy_admin)
    return ()
end

#
# Getters
#

@view
func get_value{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (val: felt):
    let (val) = value.read()
    return (val)
end

@view
func get_implementation{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = Proxy_get_implementation()
    return (address)
end

#
# Setters
#

@external
func set_value{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(val: felt):
    value.write(val)
    return ()
end
