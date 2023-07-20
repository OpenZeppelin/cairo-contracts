#[starknet::contract]
mod SnakeAccessControlMock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::access::accesscontrol::AccessControl;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::access::accesscontrol::interface::IAccessControl;
    use openzeppelin::introspection::interface::ISRC5;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControl::InternalImpl::initializer(ref unsafe_state);
        AccessControl::InternalImpl::_grant_role(ref unsafe_state, DEFAULT_ADMIN_ROLE, admin);
    }

    #[external(v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            let unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::SRC5Impl::supports_interface(@unsafe_state, interface_id)
        }
    }

    #[external(v0)]
    impl AccessControlImpl of IAccessControl<ContractState> {
        fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlImpl::has_role(@unsafe_state, role, account)
        }

        fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlImpl::get_role_admin(@unsafe_state, role)
        }

        fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlImpl::grant_role(ref unsafe_state, role, account);
        }

        fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlImpl::revoke_role(ref unsafe_state, role, account);
        }

        fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            let mut unsafe_state = AccessControl::unsafe_new_contract_state();
            AccessControl::AccessControlImpl::renounce_role(ref unsafe_state, role, account);
        }
    }
}
