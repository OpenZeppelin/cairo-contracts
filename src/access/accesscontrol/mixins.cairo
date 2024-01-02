#[starknet::component]
mod AccessControlDual {
    use openzeppelin::access::accesscontrol::interface;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[embeddable_as(AccessControlDualImpl)]
    impl AccessControlDual<
        TContractState, +HasComponent<TContractState>
    > of interface::IAccessControlDual<ComponentState<TContractState>> {
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            self.has_role(role, account)
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.get_role_admin(role)
        }

        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.grant_role(role, account);
        }

        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.revoke_role(role, account);
        }

        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.renounce_role(role, account);
        }

        fn hasRole(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            self.hasRole(role, account)
        }

        fn getRoleAdmin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.getRoleAdmin(role)
        }

        fn grantRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.grantRole(role, account);
        }

        fn revokeRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.revokeRole(role, account);
        }

        fn renounceRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.renounceRole(role, account);
        }
    }
}