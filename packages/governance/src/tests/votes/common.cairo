use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::Event;
use starknet::ContractAddress;

#[generate_trait]
pub(crate) impl VotesSpyHelpersImpl of VotesSpyHelpers {
    fn assert_event_delegate_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegator: ContractAddress,
        from_delegate: ContractAddress,
        to_delegate: ContractAddress,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("DelegateChanged"));
        keys.append_serde(delegator);
        keys.append_serde(from_delegate);
        keys.append_serde(to_delegate);

        let expected = Event { keys, data: array![] };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_delegate_votes_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegate: ContractAddress,
        previous_votes: u256,
        new_votes: u256,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("DelegateVotesChanged"));
        keys.append_serde(delegate);

        let mut data = array![];
        data.append_serde(previous_votes);
        data.append_serde(new_votes);

        let expected = Event { keys, data };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_delegate_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegator: ContractAddress,
        from_delegate: ContractAddress,
        to_delegate: ContractAddress,
    ) {
        self.assert_event_delegate_changed(contract, delegator, from_delegate, to_delegate);
        self.assert_no_events_left_from(contract);
    }

    fn assert_only_event_delegate_votes_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegate: ContractAddress,
        previous_votes: u256,
        new_votes: u256,
    ) {
        self.assert_event_delegate_votes_changed(contract, delegate, previous_votes, new_votes);
        self.assert_no_events_left_from(contract);
    }
}
