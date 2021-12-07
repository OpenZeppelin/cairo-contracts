%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from contracts.Ownable_base import (
    Ownable_initializer,
    Ownable_get_owner,
    Ownable_transfer_ownership
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
func get_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = Ownable_get_owner()
    return (owner=owner)
end

@external
func transfer_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt) -> (new_owner: felt):
    Ownable_transfer_ownership(new_owner)
    return (new_owner=new_owner)
end
