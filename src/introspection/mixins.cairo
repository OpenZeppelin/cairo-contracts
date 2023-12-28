#[starknet::component]
mod SRC5Dual {
    use openzeppelin::introspection::interface;
    use openzeppelin::introspection::src5::SRC5Component;

    #[storage]
    struct Storage {}

    #[embeddable_as(SRC5DualImpl)]
    impl ISRC5Dual<
        TContractState, +HasComponent<TContractState>
    > of interface::ISRC5Dual<ComponentState<TContractState>> {
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            self.supports_interface(interface_id)
        }

        fn supportsInterface(self: @ComponentState<TContractState>, interfaceId: felt252) -> bool {
            self.supports_interface(interfaceId)
        }
    }
}
