# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.x.0 (access/accesscontrol.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
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
func _roleAdmin(role: felt) -> (admin: felt):
end

@storage_var
func _roleMember(role: felt, account: felt) -> (hasRole: felt):
end

#
# Constructor
#

func AccessControl_initializer{
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

func AccessControl_onlyRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt):
    let (caller: felt) = get_caller_address()
    let (hasRole: felt) = AccessControl_hasRole(role, caller)
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
    let (hasRole: felt) = _roleMember.read(role, user)
    return (hasRole=hasRole)
end

func AccessControl_getRoleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt) -> (admin: felt):
    let (admin: felt) = _roleAdmin.read(role)
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
    let (admin: felt) = AccessControl_getRoleAdmin(role)
    AccessControl_onlyRole(admin)
    _grantRole(role, user)
    return ()
end

func AccessControl_revokeRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    let (admin: felt) = AccessControl_getRoleAdmin(role)
    AccessControl_onlyRole(admin)
    _revokeRole(role, user)
    return ()
end

func AccessControl_renounceRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    let (sender: felt) = get_caller_address()
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
    let (hasRole: felt) = AccessControl_hasRole(role, user)
    if hasRole == FALSE:
        let (sender: felt) = get_caller_address()
        _roleMember.write(role, user, TRUE)
        RoleGranted.emit(role, user, sender)
        return ()
    end
    return ()
end

func _revokeRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    let (hasRole: felt) = AccessControl_hasRole(role, user)
    if hasRole == TRUE:
        let (sender: felt) = get_caller_address()
        _roleMember.write(role, user, FALSE)
        RoleRevoked.emit(role, user, sender)
        return ()
    end
    return ()
end

func _setRoleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, adminRole: felt):
    let (previousAdminRole: felt) = AccessControl_getRoleAdmin(role)
    _roleAdmin.write(role, adminRole)
    RoleAdminChanged.emit(role, previousAdminRole, adminRole)
    return ()
end
