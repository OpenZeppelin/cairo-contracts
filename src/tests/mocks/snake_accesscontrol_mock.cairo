#[starknet::contract]
mod SnakeAccessControlMock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::access::accesscontrol::AccessControl;
    use openzeppelin::access::accesscontrol::AccessControl::AccessControlImpl;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControl::InternalImpl::initializer(ref unsafe_state);
        AccessControl::InternalImpl::_grant_role(ref unsafe_state, DEFAULT_ADMIN_ROLE, admin);
    }

    #[external(v0)]
    fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
        let unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlImpl::has_role(@unsafe_state, role, account)
    }

    #[external(v0)]
    fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
        let unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlImpl::get_role_admin(@unsafe_state, role)
    }

    #[external(v0)]
    fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlImpl::grant_role(ref unsafe_state, role, account);
    }

    #[external(v0)]
    fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlImpl::revoke_role(ref unsafe_state, role, account);
    }

    #[external(v0)]
    fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControlImpl::renounce_role(ref unsafe_state, role, account);
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        let unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControl::SRC5Impl::supports_interface(@unsafe_state, interface_id)
    }
}
