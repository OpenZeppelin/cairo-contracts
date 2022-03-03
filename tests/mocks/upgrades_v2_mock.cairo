# SPDX-License-Identifier: MIT

%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.upgrades.library import (
    Proxy_initializer,
    Proxy_only_admin,
    Proxy_set_implementation,
    Proxy_get_implementation,
    Proxy_set_admin,
    Proxy_get_admin
)

#
# Storage
#

@storage_var
func value_1() -> (res: felt):
end

@storage_var
func value_2() -> (res: felt):
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
# Upgrades
#

@external
func upgrade{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(new_implementation: felt):
    Proxy_only_admin()
    Proxy_set_implementation(new_implementation)
    return ()
end

#
# Getters
#

@view
func get_value_1{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (val: felt):
    let (val) = value_1.read()
    return (val)
end

@view
func get_value_2{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (val: felt):
    let (val) = value_2.read()
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

@view
func get_admin{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (admin: felt):
    let (admin) = Proxy_get_admin()
    return (admin)
end

#
# Setters
#

@external
func set_value_1{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(val: felt):
    value_1.write(val)
    return ()
end

@external
func set_value_2{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(val: felt):
    value_2.write(val)
    return ()
end

@view
func set_admin{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_admin: felt):
    Proxy_only_admin()
    Proxy_set_admin(new_admin)
    return ()
end
