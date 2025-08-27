use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent};
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
        let expected = ExpectedEvent::new()
            .key(selector!("DelegateChanged"))
            .key(delegator)
            .key(from_delegate)
            .key(to_delegate);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_delegate_votes_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegate: ContractAddress,
        previous_votes: u256,
        new_votes: u256,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("DelegateVotesChanged"))
            .key(delegate)
            .data(previous_votes)
            .data(new_votes);
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
