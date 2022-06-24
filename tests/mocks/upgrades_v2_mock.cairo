# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from openzeppelin.upgrades.library import Proxy

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
    Proxy.initializer(proxy_admin)
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
    Proxy.assert_only_admin()
    Proxy._set_implementation_hash(new_implementation)
    return ()
end

#
# Getters
#

@view
func getValue1{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (val: felt):
    let (val) = value_1.read()
    return (val)
end

@view
func getValue2{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (val: felt):
    let (val) = value_2.read()
    return (val)
end

@view
func getImplementationHash{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = Proxy.get_implementation_hash()
    return (address)
end

@view
func getAdmin{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (admin: felt):
    let (admin) = Proxy.get_admin()
    return (admin)
end

#
# Setters
#

@external
func setValue1{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(val: felt):
    value_1.write(val)
    return ()
end

@external
func setValue2{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(val: felt):
    value_2.write(val)
    return ()
end

@external
func setAdmin{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_admin: felt):
    Proxy.assert_only_admin()
    Proxy._set_admin(new_admin)
    return ()
end
