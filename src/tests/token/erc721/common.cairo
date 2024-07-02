use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721Component::{Approval, ApprovalForAll, Transfer};
use openzeppelin::token::erc721::ERC721Component;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{EventSpy, EventAssertions};
use starknet::ContractAddress;

pub(crate) fn assert_event_approval_for_all(
    ref spy: EventSpy,
    contract: ContractAddress,
    owner: ContractAddress,
    operator: ContractAddress,
    approved: bool
) {
    let expected = ERC721Component::Event::ApprovalForAll(
        ApprovalForAll { owner, operator, approved }
    );
    spy.assert_emitted(@array![(contract, expected)]);
}

pub(crate) fn assert_only_event_approval_for_all(
    ref spy: EventSpy,
    contract: ContractAddress,
    owner: ContractAddress,
    operator: ContractAddress,
    approved: bool
) {
    assert_event_approval_for_all(ref spy, contract, owner, operator, approved);
    utils::assert_no_events_left(ref spy);
}

pub(crate) fn assert_event_approval(
    ref spy: EventSpy,
    contract: ContractAddress,
    owner: ContractAddress,
    approved: ContractAddress,
    token_id: u256
) {
    let expected = ERC721Component::Event::Approval(Approval { owner, approved, token_id });
    spy.assert_emitted(@array![(contract, expected)]);
}

pub(crate) fn assert_only_event_approval(
    ref spy: EventSpy,
    contract: ContractAddress,
    owner: ContractAddress,
    approved: ContractAddress,
    token_id: u256
) {
    assert_event_approval(ref spy, contract, owner, approved, token_id);
    utils::assert_no_events_left(ref spy);
}

pub(crate) fn assert_event_transfer(
    ref spy: EventSpy,
    contract: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_id: u256
) {
    let expected = ERC721Component::Event::Transfer(Transfer { from, to, token_id });
    spy.assert_emitted(@array![(contract, expected)]);
}

pub(crate) fn assert_only_event_transfer(
    ref spy: EventSpy,
    contract: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_id: u256
) {
    assert_event_transfer(ref spy, contract, from, to, token_id);
    utils::assert_no_events_left(ref spy);
}
