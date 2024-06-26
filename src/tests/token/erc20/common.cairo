use openzeppelin::tests::utils;
use openzeppelin::token::erc20::ERC20Component::{Approval, Transfer};
use openzeppelin::token::erc20::ERC20Component;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{SpyOn, EventSpy, EventAssertions};
use starknet::ContractAddress;

pub(crate) fn assert_event_approval(
    ref spy: EventSpy,
    contract: ContractAddress,
    owner: ContractAddress,
    spender: ContractAddress,
    value: u256
) {
    let expected = ERC20Component::Event::Approval(Approval { owner, spender, value });
    spy.assert_emitted(@array![(contract, expected)]);
}

pub(crate) fn assert_only_event_approval(
    ref spy: EventSpy,
    contract: ContractAddress,
    owner: ContractAddress,
    spender: ContractAddress,
    value: u256
) {
    assert_event_approval(ref spy, contract, owner, spender, value);
    assert(spy.events.len() == 0, 'Events remaining on queue');
}

pub(crate) fn assert_event_transfer(
    ref spy: EventSpy,
    contract: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    value: u256
) {
    let expected = ERC20Component::Event::Transfer(Transfer { from, to, value });
    spy.assert_emitted(@array![(contract, expected)]);
}

pub(crate) fn assert_only_event_transfer(
    ref spy: EventSpy,
    contract: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    value: u256
) {
    assert_event_transfer(ref spy, contract, from, to, value);
    assert(spy.events.len() == 0, 'Events remaining on queue');
}
