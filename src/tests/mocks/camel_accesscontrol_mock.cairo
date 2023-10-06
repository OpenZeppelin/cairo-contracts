#[starknet::contract]
mod CamelAccessControlMock {
    use openzeppelin::access::accesscontrol::AccessControl::AccessControlCamelImpl;
    use openzeppelin::access::accesscontrol::AccessControl;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControl::InternalImpl::initializer(ref unsafe_state);
        AccessControl::InternalImpl::_grant_role(ref unsafe_state, DEFAULT_ADMIN_ROLE, admin);
    }

    #[external(v0)]
    fn hasRole(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
        let unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlCamelImpl::hasRole(@unsafe_state, role, account)
    }

    #[external(v0)]
    fn getRoleAdmin(self: @ContractState, role: felt252) -> felt252 {
        let unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlCamelImpl::getRoleAdmin(@unsafe_state, role)
    }

    #[external(v0)]
    fn grantRole(ref self: ContractState, role: felt252, account: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlCamelImpl::grantRole(ref unsafe_state, role, account);
    }

    #[external(v0)]
    fn revokeRole(ref self: ContractState, role: felt252, account: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlCamelImpl::revokeRole(ref unsafe_state, role, account);
    }

    #[external(v0)]
    fn renounceRole(ref self: ContractState, role: felt252, account: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlCamelImpl::renounceRole(ref unsafe_state, role, account);
    }

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        let unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControl::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
    }
}
