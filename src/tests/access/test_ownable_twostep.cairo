use openzeppelin::access::ownable::OwnableComponent::InternalTrait;
use openzeppelin::access::ownable::interface::{IOwnableTwoStep, IOwnableTwoStepCamelOnly};
use openzeppelin::tests::mocks::ownable_mocks::DualCaseTwoStepOwnableMock;
use openzeppelin::tests::utils::constants::{ZERO, OWNER, NEW_OWNER};
use openzeppelin::tests::utils;
use starknet::testing;

fn STATE() -> DualCaseTwoStepOwnableMock::ContractState {
    DualCaseTwoStepOwnableMock::contract_state_for_testing()
}

fn setup() -> DualCaseTwoStepOwnableMock::ContractState {
    let mut state = STATE();
    state.ownable.initializer(OWNER());
    utils::drop_event(ZERO());
    state
}

#[test]
#[available_gas(2000000)]
fn test_two_step_transfer() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.transfer_ownership(NEW_OWNER());

    // TODO: event test

    assert(state.ownable.pending_owner() == NEW_OWNER(), 'Should set pending owner');

    testing::set_caller_address(NEW_OWNER());
    state.ownable.accept_ownership();

    // TODO: event test

    assert(state.ownable.owner() == NEW_OWNER(), 'Should transfer ownership');
    assert(state.ownable.pending_owner() == ZERO(), 'Should clear pending owner');
}
