use openzeppelin::security::ReentrancyGuardComponent::InternalImpl;
use openzeppelin::security::ReentrancyGuardComponent;
use openzeppelin::tests::mocks::reentrancy_attacker_mock::Attacker;
use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcher;
use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcherTrait;
use openzeppelin::tests::mocks::reentrancy_mock::ReentrancyMock;
use openzeppelin::tests::utils;
use starknet::storage::StorageMemberAccessTrait;

fn STATE() -> ReentrancyMock::ContractState {
    ReentrancyMock::contract_state_for_testing()
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
#[available_gas(2000000)]
fn test_reentrancy_guard_start() {
    let mut state = STATE();

    assert(!state.reentrancy_guard.ReentrancyGuard_entered.read(), 'Should not be entered');
    state.reentrancy_guard.start();
    assert(state.reentrancy_guard.ReentrancyGuard_entered.read(), 'Should be entered');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ReentrancyGuard: reentrant call',))]
fn test_reentrancy_guard_start_when_started() {
    let mut state = STATE();

    state.reentrancy_guard.start();
    state.reentrancy_guard.start();
}

#[test]
#[available_gas(2000000)]
fn test_reentrancy_guard_end() {
    let mut state = STATE();

    state.reentrancy_guard.start();
    assert(state.reentrancy_guard.ReentrancyGuard_entered.read(), 'Should be entered');
    state.reentrancy_guard.end();
    assert(!state.reentrancy_guard.ReentrancyGuard_entered.read(), 'Should no longer be entered');
}

//
// Mock implementation tests
//

#[test]
#[available_gas(2000000)]
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
#[available_gas(2000000)]
#[should_panic(expected: ('ReentrancyGuard: reentrant call', 'ENTRYPOINT_FAILED'))]
fn test_local_recursion() {
    let contract = deploy_mock();
    contract.count_local_recursive(10);
}

#[test]
#[available_gas(2000000)]
#[should_panic(
    expected: ('ReentrancyGuard: reentrant call', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED')
)]
fn test_external_recursion() {
    let contract = deploy_mock();
    contract.count_external_recursive(10);
}

#[test]
#[available_gas(2000000)]
fn test_nonreentrant_function_call() {
    let contract = deploy_mock();
    contract.callback();
    assert(contract.current_count() == 1, 'Call should execute');
}
