use openzeppelin_token::erc20::ERC20Component::{Approval, Transfer};
use openzeppelin_token::erc20::ERC20Component;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::test_utils;
use starknet::ContractAddress;

pub fn assert_event_approval(
    contract: ContractAddress, owner: ContractAddress, spender: ContractAddress, value: u256
) {
    let event = test_utils::pop_log::<ERC20Component::Event>(contract).unwrap();
    let expected = ERC20Component::Event::Approval(Approval { owner, spender, value });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Approval"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(spender);
    test_utils::assert_indexed_keys(event, indexed_keys.span())
}

pub fn assert_only_event_approval(
    contract: ContractAddress, owner: ContractAddress, spender: ContractAddress, value: u256
) {
    assert_event_approval(contract, owner, spender, value);
    test_utils::assert_no_events_left(contract);
}

pub fn assert_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, value: u256
) {
    let event = test_utils::pop_log::<ERC20Component::Event>(contract).unwrap();
    let expected = ERC20Component::Event::Transfer(Transfer { from, to, value });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Transfer"));
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    test_utils::assert_indexed_keys(event, indexed_keys.span());
}

pub fn assert_only_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, value: u256
) {
    assert_event_transfer(contract, from, to, value);
    test_utils::assert_no_events_left(contract);
}
