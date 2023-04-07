#[contract]
mod Upgrades_V2 {
    use openzeppelin::upgrades::upgradeable::Upgradeable;
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;

    struct Storage {
        value: felt252,
        value2: felt252,
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

    #[external]
    fn set_value2(val: felt252) {
        value2::write(val);
    }

    #[view]
    fn get_value() -> felt252 {
        value::read()
    }

    #[view]
    fn get_value2() -> felt252 {
        value2::read()
    }
}
