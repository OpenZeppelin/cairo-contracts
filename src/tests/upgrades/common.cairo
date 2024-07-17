use openzeppelin::tests::utils::events::EventSpyExt;
use openzeppelin::upgrades::UpgradeableComponent::Upgraded;
use openzeppelin::upgrades::UpgradeableComponent;
use snforge_std::{EventSpy, EventSpyAssertionsTrait};
use starknet::{ContractAddress, ClassHash};

#[generate_trait]
pub(crate) impl UpgradableSpyHelpersImpl of UpgradableSpyHelpers {
    fn assert_event_upgraded(ref self: EventSpy, contract: ContractAddress, class_hash: ClassHash) {
        let expected = UpgradeableComponent::Event::Upgraded(Upgraded { class_hash });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_upgraded(
        ref self: EventSpy, contract: ContractAddress, class_hash: ClassHash
    ) {
        self.assert_event_upgraded(contract, class_hash);
        self.assert_no_events_left_from(contract);
    }
}
