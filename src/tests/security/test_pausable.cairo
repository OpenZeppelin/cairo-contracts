use openzeppelin::security::pausable::Pausable::InternalImpl;
use openzeppelin::security::pausable::Pausable::PausableImpl;
use openzeppelin::security::pausable::Pausable::Paused;
use openzeppelin::security::pausable::Pausable::Unpaused;
use openzeppelin::security::pausable::Pausable;
use openzeppelin::tests::utils::constants::{CALLER, ZERO};
use openzeppelin::tests::utils;
use option::OptionTrait;
use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing;

//
// Setup
//

fn STATE() -> Pausable::ContractState {
    Pausable::contract_state_for_testing()
}

//
// is_paused
//

#[test]
#[available_gas(2000000)]
fn test_is_paused() {
    let mut state = STATE();
    assert(!PausableImpl::is_paused(@state), 'Should not be paused');

    InternalImpl::_pause(ref state);
    assert(PausableImpl::is_paused(@state), 'Should be paused');

    InternalImpl::_unpause(ref state);
    assert(!PausableImpl::is_paused(@state), 'Should not be paused');
}

//
// assert_paused
//

#[test]
#[available_gas(2000000)]
fn test_assert_paused_when_paused() {
    let mut state = STATE();
    InternalImpl::_pause(ref state);
    InternalImpl::assert_paused(@state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused', ))]
fn test_assert_paused_when_not_paused() {
    let state = STATE();
    InternalImpl::assert_paused(@state);
}

//
// assert_not_paused
//

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused', ))]
fn test_assert_not_paused_when_paused() {
    let mut state = STATE();
    InternalImpl::_pause(ref state);
    InternalImpl::assert_not_paused(@state);
}

#[test]
#[available_gas(2000000)]
fn test_assert_not_paused_when_not_paused() {
    let state = STATE();
    InternalImpl::assert_not_paused(@state);
}

//
// pause
//

#[test]
#[available_gas(2000000)]
fn test_pause_when_unpaused() {
    let mut state = STATE();
    testing::set_caller_address(CALLER());

    InternalImpl::_pause(ref state);

    assert_event_paused(CALLER());
    assert(PausableImpl::is_paused(@state), 'Should be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused', ))]
fn test_pause_when_paused() {
    let mut state = STATE();
    InternalImpl::_pause(ref state);
    InternalImpl::_pause(ref state);
}

//
// unpause
//

#[test]
#[available_gas(2000000)]
fn test_unpause_when_paused() {
    let mut state = STATE();
    testing::set_caller_address(CALLER());

    InternalImpl::_pause(ref state);
    utils::drop_event(ZERO());

    InternalImpl::_unpause(ref state);

    assert_event_unpaused(CALLER());
    assert(!PausableImpl::is_paused(@state), 'Should not be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused', ))]
fn test_unpause_when_unpaused() {
    let mut state = STATE();
    assert(!PausableImpl::is_paused(@state), 'Should be paused');
    InternalImpl::_unpause(ref state);
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
