# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from openzeppelin.access.accesscontrol import AccessControl

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(admin: felt):
    AccessControl.constructor()
    AccessControl._grant_role(0, admin)
    return ()
end

@view
func hasRole{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(role: felt, user: felt) -> (hasRole: felt):
    return AccessControl.has_role(role, user)
end

@view
func getRoleAdmin{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(role: felt) -> (admin: felt):
    return AccessControl.get_role_admin(role)
end

@external
func grantRole{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(role: felt, user: felt):
    AccessControl.grant_role(role, user)
    return ()
end

@external
func revokeRole{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(role: felt, user: felt):
    AccessControl.revoke_role(role, user)
    return ()
end

@external
func renounceRole{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(role: felt, user: felt):
    AccessControl.renounce_role(role, user)
    return ()
end

# ONLY FOR MOCKS, DON'T EXPOSE IN PRODUCTION
@external
func setRoleAdmin{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(role: felt, admin: felt):
    AccessControl._set_role_admin(role, admin)
    return ()
end
