# SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func count() -> (res: felt):
end

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(init_count: felt):
    count.write(init_count)
    return ()
end

@external
func increaseCount{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(amount: felt):
    let (oldCount) = count.read()
    count.write(oldCount + amount)
    return ()
end

@view
func getCount{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = count.read()
    return (res)
end
