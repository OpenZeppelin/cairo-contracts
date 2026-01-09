use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent};
use starknet::ContractAddress;

#[generate_trait]
pub impl ERC6909SpyHelpersImpl of ERC6909SpyHelpers {
    fn assert_event_operator_set(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        approved: bool,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("OperatorSet"))
            .key(owner)
            .key(spender)
            .data(approved);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_operator_set(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        approved: bool,
    ) {
        self.assert_event_operator_set(contract, owner, spender, approved);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_approval(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        id: u256,
        amount: u256,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("Approval"))
            .key(owner)
            .key(spender)
            .key(id)
            .data(amount);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_approval(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        id: u256,
        amount: u256,
    ) {
        self.assert_event_approval(contract, owner, spender, id, amount);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_transfer(
        ref self: EventSpy,
        contract: ContractAddress,
        caller: ContractAddress,
        sender: ContractAddress,
        receiver: ContractAddress,
        id: u256,
        amount: u256,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("Transfer"))
            .data(caller)
            .key(sender)
            .key(receiver)
            .key(id)
            .data(amount);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_transfer(
        ref self: EventSpy,
        contract: ContractAddress,
        caller: ContractAddress,
        sender: ContractAddress,
        receiver: ContractAddress,
        id: u256,
        amount: u256,
    ) {
        self.assert_event_transfer(contract, caller, sender, receiver, id, amount);
        self.assert_no_events_left_from(contract);
    }
}
