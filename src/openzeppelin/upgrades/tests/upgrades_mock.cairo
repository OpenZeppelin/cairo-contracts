#[contract]
mod UpgradesMock {
    use upgrades::Upgradeable;

    struct Storage {
        value: u8,
    }

    #[constructor]
    fn constructor(_value: u8) {
        value::write(_value);
    }

    #[view]
    fn get_value() -> u8 {
        value::read()
    }

    #[external]
    fn upgrade_contract(class_hash: felt) {
        Upgradeable::upgrade(class_hash);
    }
}
