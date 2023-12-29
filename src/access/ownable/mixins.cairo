#[starknet::component]
mod OwnableDual {
    use openzeppelin::access::ownable::interface;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[embeddable_as(OwnableDualImpl)]
    impl IOwnableDual<
        TContractState, +HasComponent<TContractState>
    > of interface::IOwnableDual<ComponentState<TContractState>> {
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner()
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            self.transfer_ownership(new_owner);
        }

        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            self.renounce_ownership();
        }

        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            self.transferOwnership(newOwner);
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            self.renounceOwnership();
        }
    }
}
