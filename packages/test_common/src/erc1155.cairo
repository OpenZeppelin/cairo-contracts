use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{PUBKEY, TOKEN_ID, TOKEN_ID_2, TOKEN_VALUE, TOKEN_VALUE_2};
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::Event;
use starknet::ContractAddress;

pub fn setup_receiver() -> ContractAddress {
    utils::declare_and_deploy("DualCaseERC1155ReceiverMock", array![])
}

pub fn setup_account() -> ContractAddress {
    let calldata = array![PUBKEY];
    utils::declare_and_deploy("DualCaseAccountMock", calldata)
}

pub fn deploy_another_account_at(existing: ContractAddress, target_address: ContractAddress) {
    let calldata = array![PUBKEY];
    utils::deploy_another_at(existing, target_address, calldata);
}

pub fn setup_src5() -> ContractAddress {
    utils::declare_and_deploy("SRC5Mock", array![])
}

pub fn get_ids_and_values() -> (Span<u256>, Span<u256>) {
    let ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, TOKEN_VALUE_2].span();
    (ids, values)
}

pub fn get_ids_and_split_values(split: u256) -> (Span<u256>, Span<u256>) {
    let ids = array![TOKEN_ID, TOKEN_ID].span();
    let values = array![TOKEN_VALUE - split, split].span();
    (ids, values)
}

#[generate_trait]
pub impl ERC1155SpyHelpersImpl of ERC1155SpyHelpers {
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

    fn assert_event_transfer_single(
        ref self: EventSpy,
        contract: ContractAddress,
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("TransferSingle"));
        keys.append_serde(operator);
        keys.append_serde(from);
        keys.append_serde(to);

        let mut data = array![];
        data.append_serde(token_id);
        data.append_serde(value);

        let expected = Event { keys, data };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_transfer_single(
        ref self: EventSpy,
        contract: ContractAddress,
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
    ) {
        self.assert_event_transfer_single(contract, operator, from, to, token_id, value);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_transfer_batch(
        ref self: EventSpy,
        contract: ContractAddress,
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
    ) {
        let mut keys = array![];
        keys.append_serde(selector!("TransferBatch"));
        keys.append_serde(operator);
        keys.append_serde(from);
        keys.append_serde(to);

        let mut data = array![];
        data.append_serde(token_ids);
        data.append_serde(values);

        let expected = Event { keys, data };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_transfer_batch(
        ref self: EventSpy,
        contract: ContractAddress,
        operator: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
    ) {
        self.assert_event_transfer_batch(contract, operator, from, to, token_ids, values);
        self.assert_no_events_left_from(contract);
    }
}
