// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.5.1 (access/accesscontrol/library.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.utils.constants.library import IACCESSCONTROL_ID

//
// Events
//

@event
func RoleGranted(role: felt, account: felt, sender: felt) {
}

@event
func RoleRevoked(role: felt, account: felt, sender: felt) {
}

@event
func RoleAdminChanged(role: felt, previousAdminRole: felt, newAdminRole: felt) {
}

//
// Storage
//

@storage_var
func AccessControl_role_admin(role: felt) -> (admin: felt) {
}

@storage_var
func AccessControl_role_member(role: felt, account: felt) -> (has_role: felt) {
}

namespace AccessControl {
    //
    // Initializer
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        ERC165.register_interface(IACCESSCONTROL_ID);
        return ();
    }

    //
    // Modifier
    //

    func assert_only_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt
    ) {
        alloc_locals;
        let (caller) = get_caller_address();
        let (authorized) = has_role(role, caller);
        with_attr error_message("AccessControl: caller is missing role {role}") {
            assert authorized = TRUE;
        }
        return ();
    }

    //
    // Getters
    //

    func has_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt, user: felt
    ) -> (has_role: felt) {
        return AccessControl_role_member.read(role, user);
    }

    func get_role_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt
    ) -> (admin: felt) {
        return AccessControl_role_admin.read(role);
    }

    //
    // Externals
    //

    func grant_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt, user: felt
    ) {
        let (admin: felt) = get_role_admin(role);
        assert_only_role(admin);
        _grant_role(role, user);
        return ();
    }

    func revoke_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt, user: felt
    ) {
        let (admin: felt) = get_role_admin(role);
        assert_only_role(admin);
        _revoke_role(role, user);
        return ();
    }

    func renounce_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt, user: felt
    ) {
        let (caller: felt) = get_caller_address();
        with_attr error_message("AccessControl: can only renounce roles for self") {
            assert user = caller;
        }
        _revoke_role(role, user);
        return ();
    }

    //
    // Unprotected
    //

    func _grant_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt, user: felt
    ) {
        let (user_has_role: felt) = has_role(role, user);
        if (user_has_role == FALSE) {
            let (caller: felt) = get_caller_address();
            AccessControl_role_member.write(role, user, TRUE);
            RoleGranted.emit(role, user, caller);
            return ();
        }
        return ();
    }

    func _revoke_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt, user: felt
    ) {
        let (user_has_role: felt) = has_role(role, user);
        if (user_has_role == TRUE) {
            let (caller: felt) = get_caller_address();
            AccessControl_role_member.write(role, user, FALSE);
            RoleRevoked.emit(role, user, caller);
            return ();
        }
        return ();
    }

    func _set_role_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        role: felt, admin_role: felt
    ) {
        let (previous_admin_role: felt) = get_role_admin(role);
        AccessControl_role_admin.write(role, admin_role);
        RoleAdminChanged.emit(role, previous_admin_role, admin_role);
        return ();
    }
}
