use openzeppelin::security::reentrancyguard::ReentrancyGuard;
use openzeppelin::tests::mocks::reentrancy_mock::ReentrancyMock;
use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcher;
use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcherTrait;
use openzeppelin::tests::mocks::reentrancy_attacker_mock::Attacker;

use array::ArrayTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;
use traits::TryInto;

fn deploy_mock() -> IReentrancyMockDispatcher {
    let calldata = ArrayTrait::<felt252>::new();
    let (address, _) = starknet::deploy_syscall(
        ReentrancyMock::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    IReentrancyMockDispatcher { contract_address: address }
}

fn deploy_attacker() -> ContractAddress {
    let calldata = ArrayTrait::<felt252>::new();
    let (address, _) = starknet::deploy_syscall(
        Attacker::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    address
}

//
// ReentrancyGuard direct call tests
//

#[test]
#[available_gas(2000000)]
fn test_reentrancy_guard_start() {
    assert(!ReentrancyGuard::entered::read(), 'Guard should not be active');
    ReentrancyGuard::start();
    assert(ReentrancyGuard::entered::read(), 'Guard should be active');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ReentrancyGuard: reentrant call', ))]
fn test_reentrancy_guard_start_when_started() {
    ReentrancyGuard::start();
    ReentrancyGuard::start();
}

#[test]
#[available_gas(2000000)]
fn test_reentrancy_guard_end() {
    ReentrancyGuard::start();
    ReentrancyGuard::end();
    assert(!ReentrancyGuard::entered::read(), 'Guard should not be active');
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
    let attacker_addr = deploy_attacker();

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
