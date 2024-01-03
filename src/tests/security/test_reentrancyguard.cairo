use openzeppelin::security::ReentrancyGuardComponent::InternalImpl;
use openzeppelin::security::ReentrancyGuardComponent;
use openzeppelin::tests::mocks::reentrancy_mocks::{
    Attacker, ReentrancyMock, IReentrancyMockDispatcher, IReentrancyMockDispatcherTrait
};
use openzeppelin::tests::utils;
use starknet::storage::StorageMemberAccessTrait;

type ComponentState = ReentrancyGuardComponent::ComponentState<ReentrancyMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ReentrancyGuardComponent::component_state_for_testing()
}

fn deploy_mock() -> IReentrancyMockDispatcher {
    let calldata = array![];
    let address = utils::deploy(ReentrancyMock::TEST_CLASS_HASH, calldata);
    IReentrancyMockDispatcher { contract_address: address }
}

//
// ReentrancyGuard direct call tests
//

#[test]
fn test_reentrancy_guard_start() {
    let mut state = COMPONENT_STATE();

    assert(!state.ReentrancyGuard_entered.read(), 'Should not be entered');
    state.start();
    assert(state.ReentrancyGuard_entered.read(), 'Should be entered');
}

#[test]
#[should_panic(expected: ('ReentrancyGuard: reentrant call',))]
fn test_reentrancy_guard_start_when_started() {
    let mut state = COMPONENT_STATE();

    state.start();
    state.start();
}

#[test]
fn test_reentrancy_guard_end() {
    let mut state = COMPONENT_STATE();

    state.start();
    assert(state.ReentrancyGuard_entered.read(), 'Should be entered');
    state.end();
    assert(!state.ReentrancyGuard_entered.read(), 'Should no longer be entered');
}

//
// Mock implementation tests
//

#[test]
#[should_panic(
    expected: (
        'ReentrancyGuard: reentrant call',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED'
    ),
)]
fn test_remote_callback() {
    let contract = deploy_mock();

    // Deploy attacker
    let calldata = ArrayTrait::new();
    let attacker_addr = utils::deploy(Attacker::TEST_CLASS_HASH, calldata);

    contract.count_and_call(attacker_addr);
}

#[test]
#[should_panic(expected: ('ReentrancyGuard: reentrant call', 'ENTRYPOINT_FAILED'))]
fn test_local_recursion() {
    let contract = deploy_mock();
    contract.count_local_recursive(10);
}

#[test]
#[should_panic(
    expected: ('ReentrancyGuard: reentrant call', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED')
)]
fn test_external_recursion() {
    let contract = deploy_mock();
    contract.count_external_recursive(10);
}

#[test]
fn test_nonreentrant_function_call() {
    let contract = deploy_mock();
    contract.callback();
    assert(contract.current_count() == 1, 'Call should execute');
}
