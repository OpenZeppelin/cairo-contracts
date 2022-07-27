# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.1 (access/accesscontrol/IAccessControl.cairo)

%lang starknet

@contract_interface
namespace IAccessControl:
    func has_role(role: felt, user: felt) -> (has_role: felt):
    end

    func get_role_admin(role: felt) -> (admin: felt):
    end

    func grant_role(role: felt, user: felt):
    end

    func revoke_role(role: felt, user: felt):
    end

    func renounce_role(role: felt, user: felt):
    end
end