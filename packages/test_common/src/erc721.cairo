use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::Event;
use starknet::ContractAddress;

#[generate_trait]
pub impl ERC721SpyHelpersImpl of ERC721SpyHelpers {
    fn assert_event_approval_for_all(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        operator: ContractAddress,
        approved: bool,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("ApprovalForAll"));
        keys.append_serde(owner);
        keys.append_serde(operator);

        let mut data = array![];
        data.append_serde(approved);

        let expected = Event { keys, data };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_approval_for_all(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        operator: ContractAddress,
        approved: bool,
    ) {
        self.assert_event_approval_for_all(contract, owner, operator, approved);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_approval(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        approved: ContractAddress,
        token_id: u256,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("Approval"));
        keys.append_serde(owner);
        keys.append_serde(approved);
        keys.append_serde(token_id);

        let expected = Event { keys, data: array![] };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_approval(
        ref self: EventSpy,
        contract: ContractAddress,
        owner: ContractAddress,
        approved: ContractAddress,
        token_id: u256,
    ) {
        self.assert_event_approval(contract, owner, approved, token_id);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_transfer(
        ref self: EventSpy,
        contract: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("Transfer"));
        keys.append_serde(from);
        keys.append_serde(to);
        keys.append_serde(token_id);

        let expected = Event { keys, data: array![] };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_transfer(
        ref self: EventSpy,
        contract: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
    ) {
        self.assert_event_transfer(contract, from, to, token_id);
        self.assert_no_events_left_from(contract);
    }
}
