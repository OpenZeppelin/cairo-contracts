# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.2.0 (access/accesscontrol.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.introspection.ERC165 import ERC165
from openzeppelin.utils.constants import IACCESSCONTROL_ID

#
# Events
#

@event
func RoleGranted(role: felt, account: felt, sender: felt):
end

@event
func RoleRevoked(role: felt, account: felt, sender: felt):
end

@event
func RoleAdminChanged(role: felt, previousAdminRole: felt, newAdminRole: felt):
end

#
# Storage
#

@storage_var
func AccessControl_role_admin(role: felt) -> (admin: felt):
end

@storage_var
func AccessControl_role_member(role: felt, account: felt) -> (has_role: felt):
end

namespace AccessControl:
    #
    # Initializer
    #

    func initializer{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }():
        ERC165.register_interface(IACCESSCONTROL_ID)
        return ()
    end

    #
    # Modifier
    #

    func assert_only_role{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt):
        alloc_locals
        let (caller) = get_caller_address()
        let (authorized) = has_role(role, caller)
        with_attr error_message("AccessControl: caller is missing role {role}"):
            assert authorized = TRUE
        end
        return ()
    end

    #
    # Getters
    #

    func has_role{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt, user: felt) -> (has_role: felt):
        let (authorized: felt) = AccessControl_role_member.read(role, user)
        return (authorized)
    end

    func get_role_admin{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt) -> (admin: felt):
        let (admin: felt) = AccessControl_role_admin.read(role)
        return (admin=admin)
    end

    #
    # Externals
    #

    func grant_role{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt, user: felt):
        let (admin: felt) = get_role_admin(role)
        assert_only_role(admin)
        _grant_role(role, user)
        return ()
    end

    func revoke_role{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt, user: felt):
        let (admin: felt) = get_role_admin(role)
        assert_only_role(admin)
        _revoke_role(role, user)
        return ()
    end

    func renounce_role{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt, user: felt):
        let (caller: felt) = get_caller_address()
        with_attr error_message("AccessControl: can only renounce roles for self"):
            assert user = caller
        end
        _revoke_role(role, user)
        return ()
    end

    #
    # Unprotected
    #

    func _grant_role{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt, user: felt):
        let (user_has_role: felt) = has_role(role, user)
        if user_has_role == FALSE:
            let (caller: felt) = get_caller_address()
            AccessControl_role_member.write(role, user, TRUE)
            RoleGranted.emit(role, user, caller)
            return ()
        end
        return ()
    end

    func _revoke_role{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt, user: felt):
        let (user_has_role: felt) = has_role(role, user)
        if user_has_role == TRUE:
            let (caller: felt) = get_caller_address()
            AccessControl_role_member.write(role, user, FALSE)
            RoleRevoked.emit(role, user, caller)
            return ()
        end
        return ()
    end

    func _set_role_admin{
            syscall_ptr : felt*,
            pedersen_ptr : HashBuiltin*,
            range_check_ptr
        }(role: felt, admin_role: felt):
        let (previous_admin_role: felt) = get_role_admin(role)
        AccessControl_role_admin.write(role, admin_role)
        RoleAdminChanged.emit(role, previous_admin_role, admin_role)
        return ()
    end
end
