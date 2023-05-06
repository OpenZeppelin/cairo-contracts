use openzeppelin::tests::mocks::reentrancy_attacker_mock::ReentrancyAttackerMock;
use openzeppelin::tests::mocks::reentrancy_mock::ReentrancyMock;

use starknet::{ContractAddress, contract_address_const};

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ReentrancyGuard: reentrant call', ))]
#[ignore] // dispatcher calls not yet supported in tests
fn test_reentrancy_guard_remote_callback() {
    // Get attacker contract address placeholder
    let attacker_address: ContractAddress = contract_address_const::<123>();

    // Execute remote callback
    ReentrancyMock::count_and_call(attacker_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ReentrancyGuard: reentrant call', ))]
fn test_reentrancy_guard_local_recursion() {
    ReentrancyMock::count_local_recursive(10);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ReentrancyGuard: reentrant call', ))]
#[ignore] // dispatcher calls not yet supported in tests
fn test_reentrancy_guard_external_recursion() {
    ReentrancyMock::count_external_recursive(10);
}

#[test]
#[available_gas(2000000)]
fn test_reentrancy_guard() {
    ReentrancyMock::callback();
    assert(ReentrancyMock::current_count() == 1, 'Should allow non-reentrant call');
}
