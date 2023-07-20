#[starknet::contract]
mod CamelAccessControlMock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::access::accesscontrol::AccessControl;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::access::accesscontrol::interface::IAccessControlCamel;
    use openzeppelin::introspection::interface::ISRC5Camel;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControl::InternalImpl::initializer(ref unsafe_state);
        AccessControl::InternalImpl::_grant_role(ref unsafe_state, DEFAULT_ADMIN_ROLE, admin);
    }

    #[external(v0)]
    impl SRC5CamelImpl of ISRC5Camel<ContractState> {
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            let unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
        }
    }

    #[external(v0)]
    impl AccessControlCamelImpl of IAccessControlCamel<ContractState> {
        fn hasRole(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlCamelImpl::hasRole(@unsafe_state, role, account)
        }

        fn getRoleAdmin(self: @ContractState, role: felt252) -> felt252 {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlCamelImpl::getRoleAdmin(@unsafe_state, role)
        }

        fn grantRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlCamelImpl::grantRole(ref unsafe_state, role, account);
        }

        fn revokeRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlCamelImpl::revokeRole(ref unsafe_state, role, account);
        }

        fn renounceRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlCamelImpl::renounceRole(ref unsafe_state, role, account);
        }
    }
}
