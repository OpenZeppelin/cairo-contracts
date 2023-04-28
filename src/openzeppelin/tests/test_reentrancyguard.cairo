use openzeppelin::tests::mocks::reentrancy_attacker_mock::ReentrancyAttackerMock;
use openzeppelin::tests::mocks::reentrancy_mock::ReentrancyMock;

use starknet::ContractAddress;

#[test]
#[available_gas(2000000)]
// #[should_panic(expected: ('ReentrancyGuard: reentrant call', ))]
fn test_reentrancy_guard_remote_callback() {
    // todo: requires call_contract_syscall

    // // Get attacker contract address/pseudo syntax
    // let attacker_address: ContractAddress = ReentrancyAttackerMock.get_contract_address();

    // // Get mock contract address/pseudo syntax
    // let mock_address: ContractAddress = ReentrancyMock.get_contract_address();

    // // Execute remote callback
    // ReentrancyMock::count_and_call(attacker_address);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ReentrancyGuard: reentrant call', ))]
fn test_reentrancy_guard_local_recursion() {
    ReentrancyMock::count_local_recursive(10);
}

#[test]
#[available_gas(2000000)]
// #[should_panic(expected: ('ReentrancyGuard: reentrant call', ))]
fn test_reentrancy_guard_external_recursion() {
    // todo: requires call_contract_syscall

    // ReentrancyMock::count_external_recursive(10);
}

#[test]
#[available_gas(2000000)]
fn test_reentrancy_guard() {
    ReentrancyMock::callback();
    assert(ReentrancyMock::current_count() == 1, 'Should allow non-reentrant call');
}
