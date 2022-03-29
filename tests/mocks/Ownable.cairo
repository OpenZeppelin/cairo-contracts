# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from openzeppelin.access.ownable import (
    Ownable_initializer,
    Ownable_owner,
    Ownable_transferOwnership,
    Ownable_renounceOwnership
)

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt):
    Ownable_initializer(owner)
    return ()
end

@external
func owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = Ownable_owner()
    return (owner=owner)
end

@external
func transferOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(newOwner: felt):
    Ownable_transferOwnership(newOwner)
    return ()
end

@external
func renounceOwnership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    Ownable_renounceOwnership()
    return ()
end
