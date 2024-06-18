use openzeppelin::tests::utils::constants::ZERO;
use openzeppelin::tests::utils;
use openzeppelin::upgrades::UpgradeableComponent::Upgraded;
use openzeppelin::upgrades::UpgradeableComponent;
use starknet::{ContractAddress, ClassHash};

pub(crate) fn assert_event_upgraded(contract: ContractAddress, class_hash: ClassHash) {
    let event = utils::pop_log::<UpgradeableComponent::Event>(contract).unwrap();
    let expected = UpgradeableComponent::Event::Upgraded(Upgraded { class_hash });
    assert!(event == expected);
}

pub(crate) fn assert_only_event_upgraded(contract: ContractAddress, class_hash: ClassHash) {
    assert_event_upgraded(contract, class_hash);
    utils::assert_no_events_left(ZERO());
}
