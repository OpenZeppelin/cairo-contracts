use upgrades::tests::upgrades_mock::UpgradesMock;

#[test]
#[available_gas(2000000)]
fn test_default_behavior() {
    let value: u8 = UpgradesMock::get_value();
}
