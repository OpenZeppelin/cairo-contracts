use starknet::ContractAddress;

#[starknet::interface]
trait IOwnableMixin<TState> {
    // IOwnable
    fn owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);

    // IOwnableCamelOnly
    fn transferOwnership(ref self: TState, newOwner: ContractAddress);
    fn renounceOwnership(ref self: TState);
}

#[starknet::component]
mod OwnableMixin {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::OwnableComponent::{OwnableImpl, OwnableCamelOnlyImpl};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[embeddable_as(OwnableMixinImpl)]
    impl OwnableMixin<
        TContractState,
        +HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::IOwnableMixin<ComponentState<TContractState>> {
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            let ownable = self.get_ownable();
            ownable.owner()
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            let mut ownable = self.get_ownable_mut();
            ownable.transfer_ownership(new_owner);
        }

        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            let mut ownable = self.get_ownable_mut();
            ownable.renounce_ownership();
        }

        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            let mut ownable = self.get_ownable_mut();
            ownable.transferOwnership(newOwner);
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            let mut ownable = self.get_ownable_mut();
            ownable.renounceOwnership();
        }
    }

    #[generate_trait]
    impl GetOwnableImpl<
        TContractState,
        +HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetOwnableTrait<TContractState> {
        fn get_ownable(
            self: @ComponentState<TContractState>
        ) -> @OwnableComponent::ComponentState::<TContractState> {
            let contract = self.get_contract();
            OwnableComponent::HasComponent::<TContractState>::get_component(contract)
        }

        fn get_ownable_mut(
            ref self: ComponentState<TContractState>
        ) -> OwnableComponent::ComponentState::<TContractState> {
            let mut contract = self.get_contract_mut();
            OwnableComponent::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }
}
