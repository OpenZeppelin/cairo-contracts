%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

#
# Storage variables
#

@storage_var
func Proxy_implementation_address() -> (implementation_address: felt):
end

#
# Upgrades
#

func Proxy_set_implementation{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(new_implementation: felt):
    Proxy_implementation_address.write(new_implementation)
    return ()
end
