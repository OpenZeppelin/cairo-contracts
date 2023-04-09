#[contract]
mod Upgrades_V1 {
    use openzeppelin::upgrades::upgradeable::Upgradeable;
    use starknet::class_hash::ClassHash;
    use starknet::ContractAddress;

    struct Storage {
        value: felt252
    }

    #[constructor]
    fn constructor(proxy_admin: ContractAddress) {
        Upgradeable::initializer(proxy_admin);
    }

    #[external]
    fn set_admin(new_admin: ContractAddress) {
        Upgradeable::assert_only_admin();
        Upgradeable::_set_admin(new_admin);
    }

    #[external]
    fn upgrade(new_hash: ClassHash) {
        Upgradeable::assert_only_admin();
        Upgradeable::_upgrade(new_hash);
    }

    #[external]
    fn set_value(val: felt252) {
        value::write(val);
    }

    #[view]
    fn get_admin() -> ContractAddress {
        Upgradeable::get_admin()
    }

    #[view]
    fn get_value() -> felt252 {
        value::read()
    }
}
