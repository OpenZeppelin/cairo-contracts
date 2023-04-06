#[contract]
mod Upgrades_V2 {
    use openzeppelin::upgrades::upgradable::Upgradable;
    use starknet::ContractAddress;

    struct Storage {
        value: felt252
    }

    fn initializer(proxy_admin: ContractAddress) {
        Upgradable::initializer(proxy_admin);
    }

}