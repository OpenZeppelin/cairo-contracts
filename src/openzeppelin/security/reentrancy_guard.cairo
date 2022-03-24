# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (security/reentrancyguard.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.openzeppelin.utils.constants import TRUE, FALSE

@storage_var
func _notEntered() -> (res: felt):
end

@external
func ReentrancyGuard_start{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (initialized) = _notEntered.read()
    with_attr error_message("ReentrancyGuard: reentrant call"):
        assert initialized = TRUE
    end
    _notEntered.write(FALSE)
    return ()
end

func ReentrancyGuard_end{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    _notEntered.write(TRUE)
    return ()
end