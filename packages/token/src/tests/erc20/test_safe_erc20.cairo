use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_test_common::erc20::deploy_erc20;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{OWNER, RECIPIENT, SPENDER, SUPPLY, VALUE};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address, test_address};
use crate::erc20::utils::SafeERC20DispatcherTrait;

//
// Setup
//

fn setup_token_held_by_test() -> IERC20Dispatcher {
    deploy_erc20(test_address(), SUPPLY)
}

fn deploy_failing_token() -> IERC20Dispatcher {
    let address = utils::declare_and_deploy("ERC20ReturnFalseMock", array![]);
    IERC20Dispatcher { contract_address: address }
}

//
// safe_transfer
//

#[test]
fn safe_transfer_moves_tokens() {
    let token = setup_token_held_by_test();

    token.safe_transfer(RECIPIENT, VALUE);

    assert_eq!(token.balance_of(RECIPIENT), VALUE);
    assert_eq!(token.balance_of(test_address()), SUPPLY - VALUE);
}

#[test]
#[should_panic(expected: 'SafeERC20: failed operation')]
fn safe_transfer_reverts_on_false_return() {
    let token = deploy_failing_token();
    token.safe_transfer(RECIPIENT, VALUE);
}

//
// safe_transfer_from
//

#[test]
fn safe_transfer_from_moves_tokens() {
    let token = deploy_erc20(OWNER, SUPPLY);

    start_cheat_caller_address(token.contract_address, OWNER);
    token.approve(test_address(), VALUE);
    stop_cheat_caller_address(token.contract_address);

    token.safe_transfer_from(OWNER, RECIPIENT, VALUE);

    assert_eq!(token.balance_of(RECIPIENT), VALUE);
    assert_eq!(token.balance_of(OWNER), SUPPLY - VALUE);
}

#[test]
#[should_panic(expected: 'SafeERC20: failed operation')]
fn safe_transfer_from_reverts_on_false_return() {
    let token = deploy_failing_token();
    token.safe_transfer_from(OWNER, RECIPIENT, VALUE);
}

//
// safe_increase_allowance
//

#[test]
fn safe_increase_allowance_increases_from_existing_value() {
    let token = setup_token_held_by_test();

    token.approve(SPENDER, VALUE);
    token.safe_increase_allowance(SPENDER, VALUE);

    assert_eq!(token.allowance(test_address(), SPENDER), VALUE * 2);
}

#[test]
fn safe_increase_allowance_increases_from_zero() {
    let token = setup_token_held_by_test();

    token.safe_increase_allowance(SPENDER, VALUE);

    assert_eq!(token.allowance(test_address(), SPENDER), VALUE);
}

#[test]
#[should_panic(expected: 'SafeERC20: failed operation')]
fn safe_increase_allowance_reverts_on_false_return() {
    let token = deploy_failing_token();
    token.safe_increase_allowance(SPENDER, VALUE);
}

//
// safe_decrease_allowance
//

#[test]
fn safe_decrease_allowance_reduces_from_existing_value() {
    let token = setup_token_held_by_test();

    token.approve(SPENDER, VALUE * 2);
    token.safe_decrease_allowance(SPENDER, VALUE);

    assert_eq!(token.allowance(test_address(), SPENDER), VALUE);
}

#[test]
#[should_panic(expected: 'SafeERC20: failed decrease')]
fn safe_decrease_allowance_reverts_on_underflow() {
    let token = setup_token_held_by_test();

    token.approve(SPENDER, VALUE);
    token.safe_decrease_allowance(SPENDER, VALUE + 1);
}

#[test]
#[should_panic(expected: 'SafeERC20: failed decrease')]
fn safe_decrease_allowance_reverts_when_no_allowance_set() {
    let token = setup_token_held_by_test();

    token.safe_decrease_allowance(SPENDER, 1);
}
