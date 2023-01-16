// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (security/reentrancyguard/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

@storage_var
func ReentrancyGuard_entered() -> (entered: felt) {
}

namespace ReentrancyGuard {
    func start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (has_entered) = ReentrancyGuard_entered.read();
        with_attr error_message("ReentrancyGuard: reentrant call") {
            assert has_entered = FALSE;
        }
        ReentrancyGuard_entered.write(TRUE);
        return ();
    }

    func end{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        ReentrancyGuard_entered.write(FALSE);
        return ();
    }
}
