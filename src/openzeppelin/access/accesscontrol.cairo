# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.x.0 (access/accesscontrol.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.introspection.ERC165 import ERC165_register_interface
from openzeppelin.utils.constants import TRUE, FALSE, IACCESSCONTROL_ID

#
# Events
#

@event
func RoleGranted(role: Uint256, account: felt, sender: felt):
end

@event
func RoleRevoked(role: Uint256, account: felt, sender: felt):
end

@event
func RoleAdminChanged(role: Uint256, previousAdminRole: Uint256, newAdminRole: Uint256):
end

#
# Storage
#

@storage_var
func _roleAdmin(role: Uint256) -> (admin: Uint256):
end

@storage_var
func _roleMember(role: Uint256, account: felt) -> (hasRole: felt):
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

func AccessControl_onlyRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: Uint256):
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
}(role: Uint256, user: felt) -> (hasRole: felt):
    let (hasRole: felt) = _roleMember.read(role, user)
    return (hasRole=hasRole)
end

func AccessControl_getRoleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: Uint256) -> (admin: Uint256):
    let (admin: Uint256) = _roleAdmin.read(role)
    return (admin=admin)
end

#
# Externals
#

func AccessControl_grantRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: Uint256, user: felt):
    let (admin: Uint256) = AccessControl_getRoleAdmin(role)
    AccessControl_onlyRole(admin)
    _grantRole(role, user)
    return ()
end

func AccessControl_revokeRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: Uint256, user: felt):
    let (admin: Uint256) = AccessControl_getRoleAdmin(role)
    AccessControl_onlyRole(admin)
    _revokeRole(role, user)
    return ()
end

func AccessControl_renounceRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: Uint256, user: felt):
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
}(role: Uint256, user: felt):
    let (hasRole: felt) = AccessControl_hasRole(role, user)
    if hasRole == FALSE:
        let (sender: felt) = get_caller_address()
        _roleMember.write(role, user, TRUE)
        RoleGranted.emit(role, user, sender)
    end
    return ()
end

func _revokeRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: Uint256, user: felt):
    let (hasRole: felt) = AccessControl_hasRole(role, user)
    if hasRole == TRUE:
        let (sender: felt) = get_caller_address()
        _roleMember.write(role, user, FALSE)
        RoleRevoked.emit(role, user, sender)
    end
    return ()
end

func _setRoleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: Uint256, adminRole: Uint256):
    let (previousAdminRole: Uint256) = AccessControl_getRoleAdmin(role)
    _roleAdmin.write(role, adminRole)
    RoleAdminChanged.emit(role, previousAdminRole, adminRole)
    return ()
end
