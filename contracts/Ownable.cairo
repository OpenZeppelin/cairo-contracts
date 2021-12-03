%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func _owner() -> (owner: felt):
end

@view
func get_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = _owner.read()
    return (owner=owner)
end

@view
func only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = _owner.read()
    let (caller) = get_caller_address()
    assert owner = caller
    return ()
end

func ownable_initializer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt):
    _owner.write(owner)
    return ()
end

@external
func transfer_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt) -> (new_owner: felt):
    only_owner()
    _owner.write(new_owner)
    return (new_owner=new_owner)
end
