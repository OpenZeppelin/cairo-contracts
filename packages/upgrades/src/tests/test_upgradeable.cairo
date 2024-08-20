use openzeppelin_test_common::upgrades::UpgradeableSpyHelpers;
use openzeppelin_testing::constants::{CLASS_HASH_ZERO, FELT_VALUE as VALUE};
use openzeppelin_testing::{declare_class, deploy};
use openzeppelin_upgrades::tests::mocks::upgrades_mocks::{
    IUpgradesV1Dispatcher, IUpgradesV1DispatcherTrait
};
use openzeppelin_upgrades::tests::mocks::upgrades_mocks::{
    IUpgradesV2Dispatcher, IUpgradesV2DispatcherTrait
};
use snforge_std::{spy_events, ContractClass};

//
// Setup
//

fn setup_test() -> (IUpgradesV1Dispatcher, ContractClass) {
    let v1_class = declare_class("UpgradesV1");
    let v2_class = declare_class("UpgradesV2");
    let v1_contract_address = deploy(v1_class, array![]);
    let v1 = IUpgradesV1Dispatcher { contract_address: v1_contract_address };
    (v1, v2_class)
}

//
// upgrade
//

#[test]
#[should_panic(expected: ('Class hash cannot be zero',))]
fn test_upgrade_with_class_hash_zero() {
    let (v1, _) = setup_test();
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
fn test_upgraded_event() {
    let (v1, v2_class) = setup_test();
    let mut spy = spy_events();

    v1.upgrade(v2_class.class_hash);

    spy.assert_only_event_upgraded(v1.contract_address, v2_class.class_hash);
}

#[test]
fn test_new_selector_after_upgrade() {
    let (v1, v2_class) = setup_test();

    v1.upgrade(v2_class.class_hash);
    let v2 = IUpgradesV2Dispatcher { contract_address: v1.contract_address };

    v2.set_value2(VALUE);
    assert_eq!(v2.get_value2(), VALUE);
}

#[test]
fn test_state_persists_after_upgrade() {
    let (v1, v2_class) = setup_test();

    v1.set_value(VALUE);

    v1.upgrade(v2_class.class_hash);
    let v2 = IUpgradesV2Dispatcher { contract_address: v1.contract_address };

    assert_eq!(v2.get_value(), VALUE);
}

#[test]
fn test_remove_selector_passes_in_v1() {
    let (v1, _) = setup_test();

    v1.remove_selector();
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_remove_selector_fails_in_v2() {
    let (v1, v2_class) = setup_test();

    v1.upgrade(v2_class.class_hash);
    // We use the v1 dispatcher because remove_selector is not in v2 interface
    v1.remove_selector();
}
