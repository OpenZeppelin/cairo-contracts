%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.utils.constants import TRUE, FALSE

@storage_var
func _initialized() -> (res: felt):
end

@external
func initialized{ 
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = _initialized.read()
    return (res=res)
end

@external
func initialize{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (initialized) = _initialized.read()
    assert initialized = FALSE
    _initialized.write(TRUE)
    return ()
end
