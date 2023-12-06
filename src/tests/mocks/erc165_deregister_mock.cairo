#[starknet::contract]
mod ERC165DeregisterMock {
    use openzeppelin::utils;

    #[storage]
    struct Storage {
        ERC165_supported_interfaces: LegacyMap<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[generate_trait]
    #[external(v0)]
    impl ERC165DeregisterMockImpl of ExternalTrait {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            self.ERC165_supported_interfaces.read(interface_id)
        }

        fn register_interface(ref self: ContractState, interface_id: felt252) {
            self.ERC165_supported_interfaces.write(interface_id, true);
        }

        fn deregister_erc165_interface(ref self: ContractState, interface_id: felt252) {
            utils::deregister_erc165_interface(interface_id);
        }
    }
}
