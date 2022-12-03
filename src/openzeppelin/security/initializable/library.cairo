// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.5.1 (security/initializable/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

@storage_var
func Initializable_initialized() -> (initialized: felt) {
}

namespace Initializable {
    func initialized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        felt
    ) {
        return Initializable_initialized.read();
    }

    func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (is_initialized) = Initializable_initialized.read();
        with_attr error_message("Initializable: contract already initialized") {
            assert is_initialized = FALSE;
        }
        Initializable_initialized.write(TRUE);
        return ();
    }
}
