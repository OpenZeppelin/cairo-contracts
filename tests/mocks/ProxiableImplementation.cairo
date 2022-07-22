# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from openzeppelin.upgrades.library import Proxy

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
    Proxy.initializer(proxy_admin)
    return ()
end

#
# Getters
#

@view
func getValue{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (val: felt):
    let (val) = value.read()
    return (val)
end

@view
func getAdmin{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = Proxy.get_admin()
    return (address)
end

#
# Setters
#

@external
func setValue{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(val: felt):
    value.write(val)
    return ()
end

@external
func setAdmin{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(address: felt):
    Proxy.assert_only_admin()
    Proxy._set_admin(address)
    return ()
end
