use openzeppelin_token::erc721::ERC721Component::{Approval, ApprovalForAll, Transfer};
use openzeppelin_token::erc721::ERC721Component;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::test_utils;
use starknet::ContractAddress;

pub fn assert_event_approval_for_all(
    contract: ContractAddress, owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = test_utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::ApprovalForAll(
        ApprovalForAll { owner, operator, approved }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("ApprovalForAll"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(operator);
    test_utils::assert_indexed_keys(event, indexed_keys.span());
}

pub fn assert_only_event_approval_for_all(
    contract: ContractAddress, owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    assert_event_approval_for_all(contract, owner, operator, approved);
    test_utils::assert_no_events_left(contract);
}

pub fn assert_event_approval(
    contract: ContractAddress, owner: ContractAddress, approved: ContractAddress, token_id: u256
) {
    let event = test_utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::Approval(Approval { owner, approved, token_id });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Approval"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(approved);
    indexed_keys.append_serde(token_id);
    test_utils::assert_indexed_keys(event, indexed_keys.span());
}

pub fn assert_only_event_approval(
    contract: ContractAddress, owner: ContractAddress, approved: ContractAddress, token_id: u256
) {
    assert_event_approval(contract, owner, approved, token_id);
    test_utils::assert_no_events_left(contract);
}

pub fn assert_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, token_id: u256
) {
    let event = test_utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::Transfer(Transfer { from, to, token_id });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Transfer"));
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    indexed_keys.append_serde(token_id);
    test_utils::assert_indexed_keys(event, indexed_keys.span());
}

pub fn assert_only_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, token_id: u256
) {
    assert_event_transfer(contract, from, to, token_id);
    test_utils::assert_no_events_left(contract);
}
