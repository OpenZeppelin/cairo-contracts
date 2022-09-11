// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0b (upgrades/library.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_not_zero

//
// Events
//

@event
func Upgraded(implementation: felt) {
}

@event
func AdminChanged(previousAdmin: felt, newAdmin: felt) {
}

//
// Storage variables
//

@storage_var
func Proxy_implementation_hash() -> (implementation: felt) {
}

@storage_var
func Proxy_admin() -> (admin: felt) {
}

@storage_var
func Proxy_initialized() -> (initialized: felt) {
}

namespace Proxy {
    //
    // Initializer
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        proxy_admin: felt
    ) {
        let (initialized) = Proxy_initialized.read();
        with_attr error_message("Proxy: contract already initialized") {
            assert initialized = FALSE;
        }

        Proxy_initialized.write(TRUE);
        _set_admin(proxy_admin);
        return ();
    }

    //
    // Guards
    //

    func assert_only_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (caller) = get_caller_address();
        let (admin) = Proxy_admin.read();
        with_attr error_message("Proxy: caller is not admin") {
            assert admin = caller;
        }
        return ();
    }

    //
    // Getters
    //

    func get_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (implementation: felt) {
        return Proxy_implementation_hash.read();
    }

    func get_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        admin: felt
    ) {
        return Proxy_admin.read();
    }

    //
    // Unprotected
    //

    func _set_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_admin: felt
    ) {
        let (previous_admin) = get_admin();
        Proxy_admin.write(new_admin);
        AdminChanged.emit(previous_admin, new_admin);
        return ();
    }

    //
    // Upgrade
    //

    func _set_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_implementation: felt
    ) {
        with_attr error_message("Proxy: implementation hash cannot be zero") {
            assert_not_zero(new_implementation);
        }

        Proxy_implementation_hash.write(new_implementation);
        Upgraded.emit(new_implementation);
        return ();
    }
}
