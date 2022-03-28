# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (security/reentrancyguard.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.openzeppelin.utils.constants import TRUE, FALSE

@storage_var
func _not_entered() -> (res: felt):
end

@external
func ReentrancyGuard_start{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (entered) = _not_entered.read()
    with_attr error_message("ReentrancyGuard: reentrant call"):
        assert entered = TRUE
    end
    _not_entered.write(FALSE)
    return ()
end

func ReentrancyGuard_end{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    _not_entered.write(TRUE)
    return ()
end
