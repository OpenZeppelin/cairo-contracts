use openzeppelin::access::ownable::OwnableComponent::OwnershipTransferred;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::tests::utils::EventSpyExt;
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::EventSpy;
use starknet::ContractAddress;

#[generate_trait]
pub(crate) impl OwnableSpyHelpersImpl of OwnableSpyHelpers {
    fn assert_only_event_ownership_transferred(
        ref self: EventSpy,
        contract: ContractAddress,
        previous_owner: ContractAddress,
        new_owner: ContractAddress
    ) {
        self.assert_event_ownership_transferred(contract, previous_owner, new_owner);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_ownership_transferred(
        ref self: EventSpy,
        contract: ContractAddress,
        previous_owner: ContractAddress,
        new_owner: ContractAddress
    ) {
        let expected = OwnableComponent::Event::OwnershipTransferred(
            OwnershipTransferred { previous_owner, new_owner }
        );
        self.assert_emitted_single(contract, expected);
    }
}
