use openzeppelin_finance::vesting::VestingComponent;
use openzeppelin_finance::vesting::VestingComponent::AmountReleased;
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::Event;
use starknet::ContractAddress;

#[generate_trait]
pub impl VestingSpyHelpersImpl of VestingSpyHelpers {
    fn assert_only_event_amount_released(
        ref self: EventSpy, contract: ContractAddress, token: ContractAddress, amount: u256,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("AmountReleased"));
        keys.append_serde(token);

        let mut data = array![];
        data.append_serde(amount);

        let expected = Event { keys, data };
        self.assert_only_event(contract, expected);
    }
}
