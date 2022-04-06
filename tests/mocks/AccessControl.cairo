# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from openzeppelin.access.accesscontrol import (
    AccessControl_initializer,
    AccessControl_hasRole,
    AccessControl_getRoleAdmin,
    AccessControl_grantRole,
    AccessControl_revokeRole,
    AccessControl_renounceRole,
    _grantRole,
    _setRoleAdmin,
)

@constructor
func constructor{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(admin: felt):
    AccessControl_initializer()
    _grantRole(0, admin)
    return ()
end

@view
func hasRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt) -> (hasRole: felt):
    return AccessControl_hasRole(role, user)
end

@view
func getRoleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt) -> (admin: felt):
    return AccessControl_getRoleAdmin(role)
end

@external
func grantRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    AccessControl_grantRole(role, user)
    return ()
end

@external
func revokeRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    AccessControl_revokeRole(role, user)
    return ()
end

@external
func renounceRole{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, user: felt):
    AccessControl_renounceRole(role, user)
    return ()
end

# ONLY FOR MOCKS, DON'T EXPOSE IN PRODUCTION
@external
func setRoleAdmin{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(role: felt, admin: felt):
    _setRoleAdmin(role, admin)
    return ()
end
