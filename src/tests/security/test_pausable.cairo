use openzeppelin::security::PausableComponent::{InternalImpl, PausableImpl};
use openzeppelin::security::PausableComponent::{Paused, Unpaused};
use openzeppelin::tests::mocks::pausable_mock::PausableMock;
use openzeppelin::tests::utils::constants::{CALLER, ZERO};
use openzeppelin::tests::utils;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;

//
// Setup
//

fn STATE() -> PausableMock::ContractState {
    PausableMock::contract_state_for_testing()
}

//
// is_paused
//

#[test]
#[available_gas(2000000)]
fn test_is_paused() {
    let mut state = STATE();
    assert(!state.pausable.is_paused(), 'Should not be paused');

    state.pausable._pause();
    assert(state.pausable.is_paused(), 'Should be paused');

    state.pausable._unpause();
    assert(!state.pausable.is_paused(), 'Should not be paused');
}

//
// assert_paused
//

#[test]
#[available_gas(2000000)]
fn test_assert_paused_when_paused() {
    let mut state = STATE();
    state.pausable._pause();
    state.pausable.assert_paused();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused',))]
fn test_assert_paused_when_not_paused() {
    let state = STATE();
    state.pausable.assert_paused();
}

//
// assert_not_paused
//

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused',))]
fn test_assert_not_paused_when_paused() {
    let mut state = STATE();
    state.pausable._pause();
    state.pausable.assert_not_paused();
}

#[test]
#[available_gas(2000000)]
fn test_assert_not_paused_when_not_paused() {
    let state = STATE();
    state.pausable.assert_not_paused();
}

//
// pause
//

#[test]
#[available_gas(2000000)]
fn test_pause_when_unpaused() {
    let mut state = STATE();
    testing::set_caller_address(CALLER());

    state.pausable._pause();

    assert_event_paused(CALLER());
    assert(state.pausable.is_paused(), 'Should be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused',))]
fn test_pause_when_paused() {
    let mut state = STATE();
    state.pausable._pause();
    state.pausable._pause();
}

//
// unpause
//

#[test]
#[available_gas(2000000)]
fn test_unpause_when_paused() {
    let mut state = STATE();
    testing::set_caller_address(CALLER());

    state.pausable._pause();
    utils::drop_event(ZERO());

    state.pausable._unpause();

    assert_event_unpaused(CALLER());
    assert(!state.pausable.is_paused(), 'Should not be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused',))]
fn test_unpause_when_unpaused() {
    let mut state = STATE();
    assert(!state.pausable.is_paused(), 'Should be paused');
    state.pausable._unpause();
}

//
// Helpers
//

fn assert_event_paused(account: ContractAddress) {
    let event = utils::pop_log::<Paused>(ZERO()).unwrap();
    assert(event.account == account, 'Invalid `account`');
    utils::assert_no_events_left(ZERO());
}

fn assert_event_unpaused(account: ContractAddress) {
    let event = utils::pop_log::<Unpaused>(ZERO()).unwrap();
    assert(event.account == account, 'Invalid `account`');
    utils::assert_no_events_left(ZERO());
}
