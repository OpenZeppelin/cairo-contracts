// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (security/pausable/library.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

//
// Storage
//

@storage_var
func Pausable_paused() -> (paused: felt) {
}

//
// Events
//

@event
func Paused(account: felt) {
}

@event
func Unpaused(account: felt) {
}

namespace Pausable {
    func is_paused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        paused: felt
    ) {
        return Pausable_paused.read();
    }

    func assert_not_paused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (is_paused) = Pausable_paused.read();
        with_attr error_message("Pausable: paused") {
            assert is_paused = FALSE;
        }
        return ();
    }

    func assert_paused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (is_paused) = Pausable_paused.read();
        with_attr error_message("Pausable: not paused") {
            assert is_paused = TRUE;
        }
        return ();
    }

    func _pause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        assert_not_paused();
        Pausable_paused.write(TRUE);

        let (account) = get_caller_address();
        Paused.emit(account);
        return ();
    }

    func _unpause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        assert_paused();
        Pausable_paused.write(FALSE);

        let (account) = get_caller_address();
        Unpaused.emit(account);
        return ();
    }
}
