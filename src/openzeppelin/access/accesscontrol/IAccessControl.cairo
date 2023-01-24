// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (access/accesscontrol/IAccessControl.cairo)

%lang starknet

@contract_interface
namespace IAccessControl {
    func hasRole(role: felt, account: felt) -> (hasRole: felt) {
    }

    func getRoleAdmin(role: felt) -> (admin: felt) {
    }

    func grantRole(role: felt, account: felt) {
    }

    func revokeRole(role: felt, account: felt) {
    }

    func renounceRole(role: felt, account: felt) {
    }
}
