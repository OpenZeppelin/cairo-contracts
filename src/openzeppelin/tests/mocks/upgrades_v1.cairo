#[contract]
mod Upgrades_V1 {
    use openzeppelin::upgrades::upgradable::Upgradable;
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;

    struct Storage {
        value: felt252
    }

    #[constructor]
    fn constructor(proxy_admin: ContractAddress) {
        Upgradable::initializer(proxy_admin);
    }

    #[external]
    fn upgrade(new_hash: ClassHash) {
        Upgradable::_upgrade(new_hash);
    }

    #[external]
    fn set_value(val: felt252) {
        value::write(val);
    }

    #[view]
    fn get_value() -> felt252 {
        value::read()
    }
}