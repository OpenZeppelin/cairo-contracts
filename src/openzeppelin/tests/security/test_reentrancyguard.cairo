use openzeppelin::security::reentrancyguard::ReentrancyGuard;
use openzeppelin::tests::mocks::reentrancy_mock::ReentrancyMock;
use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcher;
use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcherTrait;
use openzeppelin::tests::mocks::reentrancy_attacker_mock::Attacker;
use openzeppelin::tests::utils;

fn STATE() -> ReentrancyGuard::ContractState {
    ReentrancyGuard::contract_state_for_testing()
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

    assert(!ReentrancyGuard::StorageTrait::is_entered(@state), 'Should not be entered');
    ReentrancyGuard::StorageTrait::start(ref state);
    assert(ReentrancyGuard::StorageTrait::is_entered(@state), 'Should be entered');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ReentrancyGuard: reentrant call', ))]
fn test_reentrancy_guard_start_when_started() {
    let mut state = STATE();

    ReentrancyGuard::StorageTrait::start(ref state);
    ReentrancyGuard::StorageTrait::start(ref state);
}

#[test]
#[available_gas(2000000)]
fn test_reentrancy_guard_end() {
    let mut state = STATE();

    ReentrancyGuard::StorageTrait::start(ref state);
    assert(ReentrancyGuard::StorageTrait::is_entered(@state), 'Should be entered');
    ReentrancyGuard::StorageTrait::end(ref state);
    assert(!ReentrancyGuard::StorageTrait::is_entered(@state), 'Should no longer be entered');
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
