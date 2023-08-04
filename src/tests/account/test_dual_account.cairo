use openzeppelin::account::AccountABIDispatcher;
use openzeppelin::account::AccountABIDispatcherTrait;
use openzeppelin::account::AccountCamelABIDispatcher;
use openzeppelin::account::AccountCamelABIDispatcherTrait;
use openzeppelin::account::dual_account::DualCaseAccount;
use openzeppelin::account::dual_account::DualCaseAccountABI;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::account::test_account::SIGNED_TX_DATA;
use openzeppelin::tests::mocks::account_panic_mock::CamelAccountPanicMock;
use openzeppelin::tests::mocks::account_panic_mock::SnakeAccountPanicMock;
use openzeppelin::tests::mocks::camel_account_mock::CamelAccountMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::mocks::snake_account_mock::SnakeAccountMock;
use openzeppelin::tests::utils;
use starknet::testing;

//
// Constants
//

const PUBLIC_KEY: felt252 = 0x333333;
const NEW_PUBLIC_KEY: felt252 = 0x444444;

//
// Setup
//

fn setup_snake() -> (DualCaseAccount, AccountABIDispatcher) {
    let mut calldata = array![PUBLIC_KEY];
    let target = utils::deploy(SnakeAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccount {
            contract_address: target
            }, AccountABIDispatcher {
            contract_address: target
        }
    )
}

fn setup_camel() -> (DualCaseAccount, AccountCamelABIDispatcher) {
    let mut calldata = array![PUBLIC_KEY];
    let target = utils::deploy(CamelAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccount {
            contract_address: target
            }, AccountCamelABIDispatcher {
            contract_address: target
        }
    )
}

fn setup_non_account() -> DualCaseAccount {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseAccount { contract_address: target }
}

fn setup_account_panic() -> (DualCaseAccount, DualCaseAccount) {
    let snake_target = utils::deploy(SnakeAccountPanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelAccountPanicMock::TEST_CLASS_HASH, array![]);
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
    let (snake_dispatcher, target) = setup_snake();

    testing::set_contract_address(snake_dispatcher.contract_address);

    snake_dispatcher.set_public_key(NEW_PUBLIC_KEY);
    assert(target.get_public_key() == NEW_PUBLIC_KEY, 'Should return NEW_PUBLIC_KEY');
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

#[test]
#[available_gas(2000000)]
fn test_dual_get_public_key() {
    let (snake_dispatcher, _) = setup_snake();
    assert(snake_dispatcher.get_public_key() == PUBLIC_KEY, 'Should return PUBLIC_KEY');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_get_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.get_public_key();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_get_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.get_public_key();
}

#[test]
#[available_gas(2000000)]
fn test_dual_is_valid_signature() {
    let (snake_dispatcher, target) = setup_snake();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut signature = array![data.r, data.s];

    testing::set_contract_address(snake_dispatcher.contract_address);
    target.set_public_key(data.public_key);

    let is_valid = snake_dispatcher.is_valid_signature(hash, signature);
    assert(is_valid == 'VALID', 'Should accept valid signature');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_is_valid_signature() {
    let hash = 0x0;
    let signature = array![];

    let dispatcher = setup_non_account();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_is_valid_signature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (dispatcher, _) = setup_account_panic();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
#[available_gas(2000000)]
fn test_dual_supports_interface() {
    let (snake_dispatcher, target) = setup_snake();
    assert(snake_dispatcher.supports_interface(ISRC5_ID), 'Should implement ISRC5');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_account();
    dispatcher.supports_interface(ISRC5_ID);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.supports_interface(ISRC5_ID);
}

//
// camelCase target
//

#[test]
#[available_gas(2000000)]
fn test_dual_setPublicKey() {
    let (camel_dispatcher, target) = setup_camel();

    testing::set_contract_address(camel_dispatcher.contract_address);

    camel_dispatcher.set_public_key(NEW_PUBLIC_KEY);
    assert(target.getPublicKey() == NEW_PUBLIC_KEY, 'Should return NEW_PUBLIC_KEY');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_setPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.set_public_key(NEW_PUBLIC_KEY);
}

#[test]
#[available_gas(2000000)]
fn test_dual_getPublicKey() {
    let (camel_dispatcher, _) = setup_camel();
    assert(camel_dispatcher.get_public_key() == PUBLIC_KEY, 'Should return PUBLIC_KEY');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_getPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.get_public_key();
}

#[test]
#[available_gas(2000000)]
fn test_dual_isValidSignature() {
    let (camel_dispatcher, target) = setup_camel();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut signature = array![data.r, data.s];

    testing::set_contract_address(camel_dispatcher.contract_address);
    target.setPublicKey(data.public_key);

    let is_valid = camel_dispatcher.is_valid_signature(hash, signature);
    assert(is_valid == 'VALID', 'Should accept valid signature');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_isValidSignature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (_, dispatcher) = setup_account_panic();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
#[available_gas(2000000)]
fn test_dual_supportsInterface() {
    let (camel_dispatcher, _) = setup_camel();
    assert(camel_dispatcher.supports_interface(ISRC5_ID), 'Should implement ISRC5');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_supportsInterface_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.supports_interface(ISRC5_ID);
}

