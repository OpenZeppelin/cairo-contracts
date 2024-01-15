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
    use openzeppelin::access::ownable::OwnableComponent::{OwnableImpl, OwnableCamelOnlyImpl};
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[embeddable_as(OwnableMixinImpl)]
    impl OwnableMixin<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::IOwnableMixin<ComponentState<TContractState>> {
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            let contract = self.get_contract();
            let ownable = OwnableComponent::HasComponent::<TContractState>::get_component(contract);
            ownable.owner()
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            let mut ownable = get_dep_component_mut!(ref self, Ownable);
            ownable.transfer_ownership(new_owner);
        }

        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            let mut ownable = get_dep_component_mut!(ref self, Ownable);
            ownable.renounce_ownership();
        }

        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            let mut ownable = get_dep_component_mut!(ref self, Ownable);
            ownable.transferOwnership(newOwner);
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            let mut ownable = get_dep_component_mut!(ref self, Ownable);
            ownable.renounceOwnership();
        }
    }
}
