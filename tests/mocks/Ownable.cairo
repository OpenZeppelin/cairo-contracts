# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from openzeppelin.access.ownable import Ownable

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt):
    Ownable.initializer(owner)
    return ()
end

@external
func owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = Ownable.owner()
    return (owner=owner)
end

@external
func transferOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt):
    Ownable.transfer_ownership(new_owner)
    return ()
end

@external
func renounceOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    Ownable.renounce_ownership()
    return ()
end
