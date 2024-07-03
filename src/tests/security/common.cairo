use openzeppelin::security::PausableComponent::{Paused, Unpaused};
use openzeppelin::security::PausableComponent;
use snforge_std::{EventSpy, EventAssertions};
use starknet::ContractAddress;

pub(crate) fn assert_event_paused(
    ref spy: EventSpy,
    contract: ContractAddress,
    account: ContractAddress,
) {
    let expected = PausableComponent::Event::Paused(Paused { account });
    spy.assert_emitted(@array![(contract, expected)]);
}

pub(crate) fn assert_only_event_paused(
    ref spy: EventSpy,
    contract: ContractAddress,
    account: ContractAddress,
) {
    assert_event_paused(ref spy, contract, account);
    assert(spy.events.len() == 0, 'Events remaining on queue');
}

pub(crate) fn assert_event_unpaused(
    ref spy: EventSpy,
    contract: ContractAddress,
    account: ContractAddress,
) {
    let expected = PausableComponent::Event::Unpaused(Unpaused { account });
    spy.assert_emitted(@array![(contract, expected)]);
}

pub(crate) fn assert_only_event_unpaused(
    ref spy: EventSpy,
    contract: ContractAddress,
    account: ContractAddress,
) {
    assert_event_unpaused(ref spy, contract, account);
    assert(spy.events.len() == 0, 'Events remaining on queue');
}
