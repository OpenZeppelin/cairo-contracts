# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (access/ownable.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

@event
func OwnershipTransferred(previous_owner : felt, new_owner : felt):
end

@storage_var
func Ownable_owner() -> (owner: felt):
end

func Ownable_initializer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt):
    Ownable_owner.write(owner)
    return ()
end

func Ownable_only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = Ownable_owner.read()
    let (caller) = get_caller_address()
    with_attr error_message("Ownable: caller is not the owner"):
        assert owner = caller
    end
    return ()
end

func Ownable_get_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = Ownable_owner.read()
    return (owner=owner)
end

func Ownable_transfer_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt) -> (new_owner: felt):
    Ownable_only_owner()
    let (old_owner) = Ownable_owner.read()
    Ownable_owner.write(new_owner)
    OwnershipTransferred.emit(previous_owner=old_owner, new_owner=new_owner)
    return (new_owner=new_owner)
end

func Ownable_renounce_ownership{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (new_owner : felt):
    Ownable_only_owner()
    Ownable_transfer_ownership(0)
    return (new_owner=0)
end
