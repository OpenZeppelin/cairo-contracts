use openzeppelin_upgrades::UpgradeableComponent::Upgraded;
use openzeppelin_upgrades::UpgradeableComponent;
use openzeppelin_utils::test_utils::constants::ZERO;
use openzeppelin_utils::test_utils;
use starknet::{ContractAddress, ClassHash};

pub fn assert_event_upgraded(contract: ContractAddress, class_hash: ClassHash) {
    let event = test_utils::pop_log::<UpgradeableComponent::Event>(contract).unwrap();
    let expected = UpgradeableComponent::Event::Upgraded(Upgraded { class_hash });
    assert!(event == expected);
}

pub fn assert_only_event_upgraded(contract: ContractAddress, class_hash: ClassHash) {
    assert_event_upgraded(contract, class_hash);
    test_utils::assert_no_events_left(ZERO());
}
