use openzeppelin::tests::utils;
use openzeppelin::token::erc6909::ERC6909Component::{Approval, Transfer, OperatorSet, InternalImpl};
use openzeppelin::token::erc6909::ERC6909Component;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;

// Approval
pub(crate) fn assert_event_approval(
    contract: ContractAddress,
    owner: ContractAddress,
    spender: ContractAddress,
    id: u256,
    amount: u256
) {
    let event = utils::pop_log::<ERC6909Component::Event>(contract).unwrap();
    let expected = ERC6909Component::Event::Approval(Approval { owner, spender, id, amount });
    assert!(event == expected);
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Approval"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(spender);
    indexed_keys.append_serde(id);
    utils::assert_indexed_keys(event, indexed_keys.span())
}

pub(crate) fn assert_only_event_approval(
    contract: ContractAddress,
    owner: ContractAddress,
    spender: ContractAddress,
    id: u256,
    amount: u256
) {
    assert_event_approval(contract, owner, spender, id, amount);
    utils::assert_no_events_left(contract);
}

// Transfer
pub(crate) fn assert_event_transfer(
    contract: ContractAddress,
    caller: ContractAddress,
    sender: ContractAddress,
    receiver: ContractAddress,
    id: u256,
    amount: u256
) {
    let event = utils::pop_log::<ERC6909Component::Event>(contract).unwrap();
    let expected = ERC6909Component::Event::Transfer(
        Transfer { caller, sender, receiver, id, amount }
    );
    assert!(event == expected);
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Transfer"));
    indexed_keys.append_serde(sender);
    indexed_keys.append_serde(receiver);
    indexed_keys.append_serde(id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_only_event_transfer(
    contract: ContractAddress,
    caller: ContractAddress,
    sender: ContractAddress,
    receiver: ContractAddress,
    id: u256,
    amount: u256
) {
    assert_event_transfer(contract, caller, sender, receiver, id, amount);
    utils::assert_no_events_left(contract);
}

// OperatorSet
pub(crate) fn assert_only_event_operator_set(
    contract: ContractAddress, owner: ContractAddress, spender: ContractAddress, approved: bool,
) {
    assert_event_operator_set(contract, owner, spender, approved);
    utils::assert_no_events_left(contract);
}

pub(crate) fn assert_event_operator_set(
    contract: ContractAddress, owner: ContractAddress, spender: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ERC6909Component::Event>(contract).unwrap();
    let expected = ERC6909Component::Event::OperatorSet(OperatorSet { owner, spender, approved });
    assert!(event == expected);
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OperatorSet"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(spender);
    utils::assert_indexed_keys(event, indexed_keys.span())
}
