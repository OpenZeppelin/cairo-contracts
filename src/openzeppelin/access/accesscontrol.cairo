# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.x.0 (access/accesscontrol.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.introspection.ERC165 import ERC165_register_interface
from openzeppelin.utils.constants import TRUE, FALSE, IACCESSCONTROL_ID

#
# Events
#

@event
func RoleGranted(role: felt, account: felt, sender: felt):
end

func RoleRevoked(role: felt, account: felt, sender: felt):
end

@event
func RoleAdminChanged(role: felt, previousAdminRole: felt, newAdminRole: felt):
end

#
# Storage
#

@storage_var
func AccessControl_roleAdmin(role: felt) -> (admin: felt):
end

@storage_var
func AccessControl_roleMember(role: felt, account: felt) -> (hasRole: felt):
end

#
# Constructor
#

func AccessControl_initializer{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}():
    ERC165_register_interface(IACCESSCONTROL_ID)
    return ()
end

#
# Modifier
#

func AccessControl_only_role{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt):
    let (caller) = get_caller_address()
    let (hasRole) = AccessControl_hasRole(role, caller)
    with_attr error_message("AccessControl: caller is missing role"):
        assert hasRole = TRUE
    end
    return ()
end

func AccessControl_only_roleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt):
    let (caller) = get_caller_address()
    let (admin) = AccessControl_getRoleAdmin(role)
    let (hasRole) = AccessControl_hasRole(admin, caller)
    with_attr error_message("AccessControl: caller is missing role"):
        assert hasRole = TRUE
    end
    return ()
end

#
# Getters
#

func AccessControl_hasRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt) -> (hasRole: felt):
    let (hasRole) = AccessControl_roleMember.read(role, user)
    return (hasRole=hasRole)
end

func AccessControl_getRoleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt) -> (admin: felt):
    let (admin) = AccessControl_roleAdmin.read(role)
    return (admin=admin)
end

#
# Externals
#

func AccessControl_grantRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    AccessControl_only_roleAdmin(role)
    _grantRole(role, user)
    return ()
end

func AccessControl_revokeRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    AccessControl_only_roleAdmin(role)
    _revokeRole(role, user)
    return ()
end

func AccessControl_renounceRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    let (sender) = get_caller_address()
    with_attr error_message("AccessControl: can only renounce roles for self"):
        assert user = sender
    end
    _revokeRole(role, user)
    return ()
end

#
# Internal
#

func _grantRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    let (hasRole) = AccessControl_roleMember.read(role, user)
    if hasRole == FALSE:
        let (sender) = get_caller_address()
        AccessControl_roleMember.write(role, user, TRUE)
        RoleRevoked.emit(role, user, sender)
    end
    return ()
end

func _revokeRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    let (hasRole) = AccessControl_roleMember.read(role, user)
    if hasRole == TRUE:
        let (sender) = get_caller_address()
        AccessControl_roleMember.write(role, user, FALSE)
        RoleRevoked.emit(role, user, sender)
    end
    return ()
end

func _setRoleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, adminRole: felt) -> ():
    let (previousAdminRole) = AccessControl_roleAdmin.read(role)
    AccessControl_roleAdmin.write(role, adminRole)
    RoleAdminChanged.emit(role, previousAdminRole, adminRole)
    return ()
end
