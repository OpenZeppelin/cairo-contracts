use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent};
use starknet::{ClassHash, ContractAddress};

#[generate_trait]
pub impl UpgradeableSpyHelpersImpl of UpgradeableSpyHelpers {
    fn assert_event_upgraded(ref self: EventSpy, contract: ContractAddress, class_hash: ClassHash) {
        let expected = ExpectedEvent::new().key(selector!("Upgraded")).data(class_hash);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_upgraded(
        ref self: EventSpy, contract: ContractAddress, class_hash: ClassHash,
    ) {
        self.assert_event_upgraded(contract, class_hash);
        self.assert_no_events_left_from(contract);
    }
}
