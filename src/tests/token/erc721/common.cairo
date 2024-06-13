use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721Component::{Approval, ApprovalForAll, Transfer};
use openzeppelin::token::erc721::ERC721Component;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;

pub(crate) fn assert_event_approval_for_all(
    contract: ContractAddress, owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::ApprovalForAll(
        ApprovalForAll { owner, operator, approved }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("ApprovalForAll"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(operator);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_only_event_approval_for_all(
    contract: ContractAddress, owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    assert_event_approval_for_all(contract, owner, operator, approved);
    utils::assert_no_events_left(contract);
}

pub(crate) fn assert_event_approval(
    contract: ContractAddress, owner: ContractAddress, approved: ContractAddress, token_id: u256
) {
    let event = utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::Approval(Approval { owner, approved, token_id });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Approval"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(approved);
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_only_event_approval(
    contract: ContractAddress, owner: ContractAddress, approved: ContractAddress, token_id: u256
) {
    assert_event_approval(contract, owner, approved, token_id);
    utils::assert_no_events_left(contract);
}

pub(crate) fn assert_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, token_id: u256
) {
    let event = utils::pop_log::<ERC721Component::Event>(contract).unwrap();
    let expected = ERC721Component::Event::Transfer(Transfer { from, to, token_id });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Transfer"));
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    indexed_keys.append_serde(token_id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_only_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, token_id: u256
) {
    assert_event_transfer(contract, from, to, token_id);
    utils::assert_no_events_left(contract);
}
