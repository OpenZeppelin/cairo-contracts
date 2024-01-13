use starknet::ContractAddress;

#[starknet::interface]
trait IAccessControlMixin<TState> {
    // IAccessControl
    fn has_role(self: @TState, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @TState, role: felt252) -> felt252;
    fn grant_role(ref self: TState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TState, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: TState, role: felt252, account: ContractAddress);

    // IAccessControlCamel
    fn hasRole(self: @TState, role: felt252, account: ContractAddress) -> bool;
    fn getRoleAdmin(self: @TState, role: felt252) -> felt252;
    fn grantRole(ref self: TState, role: felt252, account: ContractAddress);
    fn revokeRole(ref self: TState, role: felt252, account: ContractAddress);
    fn renounceRole(ref self: TState, role: felt252, account: ContractAddress);
}


#[starknet::component]
mod AccessControlMixin {
    use openzeppelin::access::accesscontrol::AccessControlComponent::{
        AccessControlImpl, AccessControlCamelImpl
    };
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[embeddable_as(AccessControlMixinImpl)]
    impl AccessControlMixin<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::IAccessControlMixin<ComponentState<TContractState>> {
        // IAccessControl
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            let accesscontrol = self.get_access();
            accesscontrol.has_role(role, account)
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            let accesscontrol = self.get_access();
            accesscontrol.get_role_admin(role)
        }

        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut accesscontrol = self.get_access_mut();
            accesscontrol.grant_role(role, account);
        }

        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut accesscontrol = self.get_access_mut();
            accesscontrol.revoke_role(role, account);
        }

        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut accesscontrol = self.get_access_mut();
            accesscontrol.renounce_role(role, account);
        }

        // IAccessControlCamel
        fn hasRole(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            let accesscontrol = self.get_access();
            accesscontrol.hasRole(role, account)
        }

        fn getRoleAdmin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            let accesscontrol = self.get_access();
            accesscontrol.getRoleAdmin(role)
        }

        fn grantRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut accesscontrol = self.get_access_mut();
            accesscontrol.grantRole(role, account);
        }

        fn revokeRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut accesscontrol = self.get_access_mut();
            accesscontrol.revokeRole(role, account);
        }

        fn renounceRole(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let mut accesscontrol = self.get_access_mut();
            accesscontrol.renounceRole(role, account);
        }
    }

    #[generate_trait]
    impl GetAccessControlImpl<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetAccessControlTrait<TContractState> {
        fn get_access(
            self: @ComponentState<TContractState>
        ) -> @AccessControlComponent::ComponentState::<TContractState> {
            let contract = self.get_contract();
            AccessControlComponent::HasComponent::<TContractState>::get_component(contract)
        }

        fn get_access_mut(
            ref self: ComponentState<TContractState>
        ) -> AccessControlComponent::ComponentState::<TContractState> {
            let mut contract = self.get_contract_mut();
            AccessControlComponent::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }
}
