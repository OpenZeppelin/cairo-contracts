use openzeppelin::tests::mocks::erc6909_mocks::{CamelERC6909Mock, SnakeERC6909Mock};
use openzeppelin::tests::mocks::erc6909_mocks::{CamelERC6909Panic, SnakeERC6909Panic};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{
    OWNER, RECIPIENT, SPENDER, OPERATOR, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc6909::dual6909::{DualCaseERC6909, DualCaseERC6909Trait};
use openzeppelin::token::erc6909::interface::{
    IERC6909CamelDispatcher, IERC6909CamelDispatcherTrait
};
use openzeppelin::token::erc6909::interface::{IERC6909Dispatcher, IERC6909DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing::set_contract_address;

//
// Setup
//

pub const TOKEN_ID: u256 = 420;

fn setup_snake() -> (DualCaseERC6909, IERC6909Dispatcher) {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(SUPPLY);
    let target = utils::deploy(SnakeERC6909Mock::TEST_CLASS_HASH, calldata);
    (DualCaseERC6909 { contract_address: target }, IERC6909Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualCaseERC6909, IERC6909CamelDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(SUPPLY);
    let target = utils::deploy(CamelERC6909Mock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC6909 { contract_address: target },
        IERC6909CamelDispatcher { contract_address: target }
    )
}

fn setup_non_erc6909() -> DualCaseERC6909 {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseERC6909 { contract_address: target }
}

fn setup_erc6909_panic() -> (DualCaseERC6909, DualCaseERC6909) {
    let snake_target = utils::deploy(SnakeERC6909Panic::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelERC6909Panic::TEST_CLASS_HASH, array![]);
    (
        DualCaseERC6909 { contract_address: snake_target },
        DualCaseERC6909 { contract_address: camel_target }
    )
}

//
// Case agnostic methods
//

#[test]
fn test_dual_transfer() {
    let (snake_dispatcher, snake_target) = setup_snake();
    set_contract_address(OWNER());
    assert!(snake_dispatcher.transfer(RECIPIENT(), TOKEN_ID, VALUE));
    assert_eq!(snake_target.balance_of(RECIPIENT(), TOKEN_ID), VALUE);

    let (camel_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER());
    assert!(camel_dispatcher.transfer(RECIPIENT(), TOKEN_ID, VALUE));
    assert_eq!(camel_target.balanceOf(RECIPIENT(), TOKEN_ID), VALUE);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_transfer() {
    let dispatcher = setup_non_erc6909();
    dispatcher.transfer(RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transfer_exists_and_panics() {
    let (dispatcher, _) = setup_erc6909_panic();
    dispatcher.transfer(RECIPIENT(), TOKEN_ID, VALUE);
}


#[test]
fn test_dual_approve() {
    let (snake_dispatcher, snake_target) = setup_snake();
    set_contract_address(OWNER());
    assert!(snake_dispatcher.approve(SPENDER(), TOKEN_ID, VALUE));

    let snake_allowance = snake_target.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(snake_allowance, VALUE);

    let (camel_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER());
    assert!(camel_dispatcher.approve(SPENDER(), TOKEN_ID, VALUE));

    let camel_allowance = camel_target.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(camel_allowance, VALUE);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_approve() {
    let dispatcher = setup_non_erc6909();
    dispatcher.approve(SPENDER(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_approve_exists_and_panics() {
    let (dispatcher, _) = setup_erc6909_panic();
    dispatcher.approve(SPENDER(), TOKEN_ID, VALUE);
}

//
// snake_case target
//

#[test]
fn test_dual_balance_of() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.balance_of(OWNER(), TOKEN_ID), SUPPLY);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of() {
    let dispatcher = setup_non_erc6909();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_balance_of_exists_and_panics() {
    let (dispatcher, _) = setup_erc6909_panic();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
fn test_dual_transfer_from() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    target.approve(OPERATOR(), TOKEN_ID, VALUE);

    set_contract_address(OPERATOR());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
    assert_eq!(target.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_transfer_from() {
    let dispatcher = setup_non_erc6909();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc6909_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
}

// set_operator
#[test]
fn test_dual_set_operator() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    target.set_operator(OPERATOR(), true);

    set_contract_address(OPERATOR());
    assert!(dispatcher.is_operator(OWNER(), OPERATOR()));
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_operator() {
    let dispatcher = setup_non_erc6909();
    dispatcher.set_operator(OPERATOR(), true);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_set_operator_exists_and_panics() {
    let (dispatcher, _) = setup_erc6909_panic();
    dispatcher.set_operator(OPERATOR(), true);
}

// is_operator
#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_operator() {
    let dispatcher = setup_non_erc6909();
    dispatcher.is_operator(OWNER(), OPERATOR());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_is_operator_exists_and_panics() {
    let (dispatcher, _) = setup_erc6909_panic();
    dispatcher.is_operator(OWNER(), OPERATOR());
}

//
// camelCase target
//

#[test]
fn test_dual_balanceOf() {
    let (dispatcher, _) = setup_camel();
    assert_eq!(dispatcher.balance_of(OWNER(), TOKEN_ID), SUPPLY);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc6909_panic();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
fn test_dual_transferFrom() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(OWNER());
    target.approve(OPERATOR(), TOKEN_ID, VALUE);

    set_contract_address(OPERATOR());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
    assert_eq!(target.balanceOf(RECIPIENT(), TOKEN_ID), VALUE);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc6909_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
fn test_dual_setOperator() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(OWNER());
    target.setOperator(OPERATOR(), true);

    set_contract_address(OPERATOR());
    assert!(dispatcher.is_operator(OWNER(), OPERATOR()));
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_setOperator_exists_and_panics() {
    let (_, dispatcher) = setup_erc6909_panic();
    dispatcher.set_operator(OPERATOR(), true);
}
