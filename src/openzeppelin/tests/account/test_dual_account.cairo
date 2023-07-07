use starknet::testing;

use openzeppelin::account::dual_account::DualCaseAccount;
use openzeppelin::account::dual_account::DualCaseAccountTrait;
use openzeppelin::account::AccountABICamelDispatcher;
use openzeppelin::account::AccountABICamelDispatcherTrait;
use openzeppelin::account::AccountABIDispatcher;
use openzeppelin::account::AccountABIDispatcherTrait;
use openzeppelin::tests::mocks::account_panic_mock::CamelAccountPanicMock;
use openzeppelin::tests::mocks::account_panic_mock::SnakeAccountPanicMock;
use openzeppelin::tests::mocks::camel_account_mock::CamelAccountMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::mocks::snake_account_mock::SnakeAccountMock;
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;

//
// Constants
//

const PUBLIC_KEY: felt252 = 0x333333;
const NEW_PUBLIC_KEY: felt252 = 0x444444;

//
// Setup
//

fn setup_snake() -> (DualCaseAccount, AccountABIDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append_serde(PUBLIC_KEY);
    let target = utils::deploy(SnakeAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccount {
            contract_address: target
            }, AccountABIDispatcher {
            contract_address: target
        }
    )
}

fn setup_camel() -> (DualCaseAccount, AccountABICamelDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append_serde(PUBLIC_KEY);
    let target = utils::deploy(CamelAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccount {
            contract_address: target
            }, AccountABICamelDispatcher {
            contract_address: target
        }
    )
}

fn setup_non_account() -> DualCaseAccount {
    let calldata = ArrayTrait::new();
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseAccount { contract_address: target }
}

fn setup_account_panic() -> (DualCaseAccount, DualCaseAccount) {
    let snake_target = utils::deploy(SnakeAccountPanicMock::TEST_CLASS_HASH, ArrayTrait::new());
    let camel_target = utils::deploy(CamelAccountPanicMock::TEST_CLASS_HASH, ArrayTrait::new());
    (
        DualCaseAccount {
            contract_address: snake_target
            }, DualCaseAccount {
            contract_address: camel_target
        }
    )
}

//
// snake_case target
//

#[test]
#[available_gas(2000000)]
fn test_dual_set_public_key() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();

    testing::set_contract_address(snake_dispatcher.contract_address);

    snake_dispatcher.set_public_key(NEW_PUBLIC_KEY);
    assert(snake_dispatcher.get_public_key() == NEW_PUBLIC_KEY, 'Should return NEW_PUBLIC_KEY');

    testing::set_contract_address(camel_dispatcher.contract_address);

    camel_dispatcher.set_public_key(NEW_PUBLIC_KEY);
    assert(camel_dispatcher.get_public_key() == NEW_PUBLIC_KEY, 'Should return NEW_PUBLIC_KEY');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_set_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.set_public_key(NEW_PUBLIC_KEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_set_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.set_public_key(NEW_PUBLIC_KEY);
}
