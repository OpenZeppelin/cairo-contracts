#[starknet::contract]
mod SRC5 {
    use openzeppelin::introspection::interface;

    #[storage]
    struct Storage {
        supported_interfaces: LegacyMap<felt252, bool>
    }

    #[external(v0)]
    impl SRC5Impl of interface::ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            if interface_id == interface::ISRC5_ID {
                return true;
            }
            self.supported_interfaces.read(interface_id)
        }
    }

    #[external(v0)]
    impl SRC5CamelImpl of interface::ISRC5Camel<ContractState> {
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            SRC5Impl::supports_interface(self, interfaceId)
        }
    }

    #[external(v0)]
    impl RegisterImpl of interface::RegisterTrait<ContractState> {
        fn register_interface(ref self: ContractState, interface_id: felt252) {
            self.supported_interfaces.write(interface_id, true);
        }

        fn deregister_interface(ref self: ContractState, interface_id: felt252) {
            assert(interface_id != interface::ISRC5_ID, 'SRC5: invalid id');
            self.supported_interfaces.write(interface_id, false);
        }
    }

    #[external(v0)]
    impl RegisterCamelImpl of interface::RegisterCamelTrait<ContractState> {
        fn registerInterface(ref self: ContractState, interfaceId: felt252) {
            self.supported_interfaces.write(interfaceId, true);
        }

        fn deregisterInterface(ref self: ContractState, interfaceId: felt252) {
            assert(interfaceId != interface::ISRC5_ID, 'SRC5: invalid id');
            self.supported_interfaces.write(interfaceId, false);
        }
    }
}
