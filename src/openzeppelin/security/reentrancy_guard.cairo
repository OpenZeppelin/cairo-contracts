# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (security/reentrancyguard.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.openzeppelin.utils.constants import TRUE, FALSE

@storage_var
func ReentrancyGuard_entered() -> (res: felt):
end

func ReentrancyGuard_start{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (has_entered) = _entered.read()
    with_attr error_message("ReentrancyGuard: reentrant call"):
        assert has_entered = FALSE
    end
    _entered.write(TRUE)
    return ()
end

func ReentrancyGuard_end{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    _entered.write(FALSE)
    return ()
end

