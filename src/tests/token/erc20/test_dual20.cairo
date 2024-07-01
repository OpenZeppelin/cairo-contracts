use openzeppelin::tests::utils::constants::{
    OWNER, RECIPIENT, SPENDER, OPERATOR, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::dual20::{DualCaseERC20, DualCaseERC20Trait};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{test_address, start_cheat_caller_address};

//
// Setup
//

fn setup_snake() -> (DualCaseERC20, IERC20Dispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(SUPPLY);
    calldata.append_serde(OWNER());
    let target = utils::declare_and_deploy("SnakeERC20Mock", calldata);
    (DualCaseERC20 { contract_address: target }, IERC20Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualCaseERC20, IERC20CamelDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(SUPPLY);
    calldata.append_serde(OWNER());
    let target = utils::declare_and_deploy("CamelERC20Mock", calldata);
    (DualCaseERC20 { contract_address: target }, IERC20CamelDispatcher { contract_address: target })
}

fn setup_non_erc20() -> DualCaseERC20 {
    let calldata = array![];
    let target = utils::declare_and_deploy("NonImplementingMock", calldata);
    DualCaseERC20 { contract_address: target }
}

fn setup_erc20_panic() -> (DualCaseERC20, DualCaseERC20) {
    let snake_target = utils::declare_and_deploy("SnakeERC20Panic", array![]);
    let camel_target = utils::declare_and_deploy("CamelERC20Panic", array![]);
    (
        DualCaseERC20 { contract_address: snake_target },
        DualCaseERC20 { contract_address: camel_target }
    )
}

//
// Case agnostic methods
//

#[test]
#[ignore]
fn test_dual_name() {
    let (snake_dispatcher, _) = setup_snake();
    assert_eq!(snake_dispatcher.name(), NAME());

    let (camel_dispatcher, _) = setup_camel();
    assert_eq!(camel_dispatcher.name(), NAME());
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_name() {
    let dispatcher = setup_non_erc20();
    dispatcher.name();
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_name_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.name();
}

#[test]
#[ignore]
fn test_dual_symbol() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert_eq!(snake_dispatcher.symbol(), SYMBOL());
    assert_eq!(camel_dispatcher.symbol(), SYMBOL());
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_symbol() {
    let dispatcher = setup_non_erc20();
    dispatcher.symbol();
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_symbol_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.symbol();
}

#[test]
#[ignore]
fn test_dual_decimals() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert_eq!(snake_dispatcher.decimals(), DECIMALS);
    assert_eq!(camel_dispatcher.decimals(), DECIMALS);
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_decimals() {
    let dispatcher = setup_non_erc20();
    dispatcher.decimals();
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_decimals_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.decimals();
}

#[test]
#[ignore]
fn test_dual_transfer() {
    let (snake_dispatcher, snake_target) = setup_snake();

    start_cheat_caller_address(test_address(), OWNER());
    assert!(snake_dispatcher.transfer(RECIPIENT(), VALUE));
    assert_eq!(snake_target.balance_of(RECIPIENT()), VALUE);

    let (camel_dispatcher, camel_target) = setup_camel();
    start_cheat_caller_address(test_address(), OWNER());
    assert!(camel_dispatcher.transfer(RECIPIENT(), VALUE));
    assert_eq!(camel_target.balanceOf(RECIPIENT()), VALUE);
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_transfer() {
    let dispatcher = setup_non_erc20();
    dispatcher.transfer(RECIPIENT(), VALUE);
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transfer_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.transfer(RECIPIENT(), VALUE);
}

#[test]
#[ignore]
fn test_dual_approve() {
    let (snake_dispatcher, snake_target) = setup_snake();
    start_cheat_caller_address(test_address(), OWNER());
    assert!(snake_dispatcher.approve(SPENDER(), VALUE));

    let snake_allowance = snake_target.allowance(OWNER(), SPENDER());
    assert_eq!(snake_allowance, VALUE);

    let (camel_dispatcher, camel_target) = setup_camel();
    start_cheat_caller_address(test_address(), OWNER());
    assert!(camel_dispatcher.approve(SPENDER(), VALUE));

    let camel_allowance = camel_target.allowance(OWNER(), SPENDER());
    assert_eq!(camel_allowance, VALUE);
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_approve() {
    let dispatcher = setup_non_erc20();
    dispatcher.approve(SPENDER(), VALUE);
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_approve_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.approve(SPENDER(), VALUE);
}

//
// snake_case target
//

#[test]
#[ignore]
fn test_dual_total_supply() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.total_supply(), SUPPLY);
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_total_supply() {
    let dispatcher = setup_non_erc20();
    dispatcher.total_supply();
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_total_supply_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.total_supply();
}

#[test]
#[ignore]
fn test_dual_balance_of() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY);
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of() {
    let dispatcher = setup_non_erc20();
    dispatcher.balance_of(OWNER());
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_balance_of_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.balance_of(OWNER());
}

#[test]
#[ignore]
fn test_dual_transfer_from() {
    let (dispatcher, target) = setup_snake();
    start_cheat_caller_address(test_address(), OWNER());
    target.approve(OPERATOR(), VALUE);

    start_cheat_caller_address(test_address(), OPERATOR());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
    assert_eq!(target.balance_of(RECIPIENT()), VALUE);
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_transfer_from() {
    let dispatcher = setup_non_erc20();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
}

//
// camelCase target
//

#[test]
#[ignore]
fn test_dual_totalSupply() {
    let (dispatcher, _) = setup_camel();
    assert_eq!(dispatcher.total_supply(), SUPPLY);
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_totalSupply_exists_and_panics() {
    let (_, dispatcher) = setup_erc20_panic();
    dispatcher.total_supply();
}

#[test]
#[ignore]
fn test_dual_balanceOf() {
    let (dispatcher, _) = setup_camel();
    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY);
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc20_panic();
    dispatcher.balance_of(OWNER());
}

#[test]
#[ignore]
fn test_dual_transferFrom() {
    let (dispatcher, target) = setup_camel();
    start_cheat_caller_address(test_address(), OWNER());
    target.approve(OPERATOR(), VALUE);

    start_cheat_caller_address(test_address(), OPERATOR());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
    assert_eq!(target.balanceOf(RECIPIENT()), VALUE);
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc20_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
}
