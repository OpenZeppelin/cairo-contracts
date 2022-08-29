# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.3.2 (access/accesscontrol/IAccessControl.cairo)

%lang starknet

@contract_interface
namespace IAccessControl:
    func hasRole(role: felt, account: felt) -> (hasRole: felt):
    end

    func getRoleAdmin(role: felt) -> (admin: felt):
    end

    func grantRole(role: felt, account: felt):
    end

    func revokeRole(role: felt, account: felt):
    end

    func renounceRole(role: felt, account: felt):
    end
end
