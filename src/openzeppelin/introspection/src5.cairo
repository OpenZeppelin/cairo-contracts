const ISRC5_ID: felt252 = 0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055;

#[abi]
trait ISRC5 {
    fn supports_interface(interface_id: felt252) -> bool;
}

#[contract]
mod SRC5 {
    use openzeppelin::introspection::src5;

    struct Storage {
        supported_interfaces: LegacyMap<felt252, bool>
    }

    impl SRC5Impl of src5::ISRC5 {
        fn supports_interface(interface_id: felt252) -> bool {
            if interface_id == src5::ISRC5_ID {
                return true;
            }
            supported_interfaces::read(interface_id)
        }
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        SRC5Impl::supports_interface(interface_id)
    }

    #[internal]
    fn register_interface(interface_id: felt252) {
        supported_interfaces::write(interface_id, true);
    }

    #[internal]
    fn deregister_interface(interface_id: felt252) {
        assert(interface_id != src5::ISRC5_ID, 'SRC5: invalid id');
        supported_interfaces::write(interface_id, false);
    }
}
