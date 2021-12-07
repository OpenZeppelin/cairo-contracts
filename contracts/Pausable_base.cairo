%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func Pausable_paused() -> (paused: felt):
end

@view
func paused{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (paused: felt):
    let (paused) = Pausable_paused.read()
    return (paused)
end

func Pausable_when_not_paused{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (is_paused) = Pausable_paused.read()
    assert is_paused = 0
    return ()
end

func Pausable_when_paused{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (is_paused) = Pausable_paused.read()
    assert is_paused = 1
    return ()
end

func Pausable_pause{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    Pausable_when_not_paused()
    Pausable_paused.write(1)
    return ()
end

func Pausable_unpause{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    Pausable_when_paused()
    Pausable_paused.write(0)
    return ()
end
