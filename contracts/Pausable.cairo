%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from contracts.Ownable import only_owner

@storage_var
func _paused() -> (paused: felt):
end

@view
func paused{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (paused: felt):
    let (paused) = _paused.read()
    return (paused)
end

func when_not_paused{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (is_paused) = _paused.read()
    assert is_paused = 0
    return ()
end

func when_paused{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (is_paused) = _paused.read()
    assert is_paused = 1
    return ()
end

func _pause{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    only_owner()
    when_not_paused()
    _paused.write(1)
    return ()
end

func _unpause{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    only_owner()
    when_paused()
    _paused.write(0)
    return ()
end
