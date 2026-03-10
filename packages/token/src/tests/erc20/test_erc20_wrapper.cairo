use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_interfaces::token::erc20::{
    IERC20WrapperABIDispatcher, IERC20WrapperABIDispatcherTrait,
};
use openzeppelin_test_common::erc20::{ERC20SpyHelpers, deploy_erc20};
use openzeppelin_test_common::mocks::erc20::ERC20WrapperMock;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{NAME, OWNER, RECIPIENT, SYMBOL, VALUE, ZERO};
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent, spy_events};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address, test_address};
use starknet::ContractAddress;
use crate::erc20::DefaultConfig;
use crate::erc20::ERC20Component::{ERC20Impl, InternalImpl as ERC20InternalImpl};
use crate::erc20::extensions::erc20_wrapper::ERC20WrapperComponent;
use crate::erc20::extensions::erc20_wrapper::ERC20WrapperComponent::{
    ERC20WrapperImpl, InternalImpl as WrapperInternalImpl,
};

const TOKEN_SUPPLY: u256 = VALUE * 10;
type ComponentState = ERC20WrapperComponent::ComponentState<ERC20WrapperMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC20WrapperComponent::component_state_for_testing()
}

//
// Setup
//

fn deploy_wrapper(underlying: ContractAddress) -> IERC20WrapperABIDispatcher {
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(underlying);

    let contract_address = utils::declare_and_deploy("ERC20WrapperMock", calldata);
    IERC20WrapperABIDispatcher { contract_address }
}

fn deploy_erc20_custom_decimals(
    recipient: ContractAddress, initial_supply: u256,
) -> IERC20Dispatcher {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let contract_address = utils::declare_and_deploy("ERC20CustomDecimalsMock", calldata);
    IERC20Dispatcher { contract_address }
}

fn setup_wrapped() -> (IERC20Dispatcher, IERC20WrapperABIDispatcher) {
    let underlying = deploy_erc20(OWNER, TOKEN_SUPPLY);
    let wrapper = deploy_wrapper(underlying.contract_address);
    (underlying, wrapper)
}

//
// initializer
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let underlying = deploy_erc20(OWNER, TOKEN_SUPPLY);
    state.initializer(underlying.contract_address);

    assert_eq!(state.underlying(), underlying.contract_address);
}

#[test]
#[should_panic(expected: 'Wrapper: invalid underlying')]
fn initializer_reverts_on_zero_underlying() {
    let mut state = COMPONENT_STATE();
    state.initializer(ZERO);
}

#[test]
#[should_panic(expected: 'Wrapper: invalid underlying')]
fn initializer_reverts_on_self_underlying() {
    let mut state = COMPONENT_STATE();
    state.initializer(test_address());
}

#[test]
#[should_panic(expected: 'Wrapper: invalid decimals')]
fn initializer_reverts_on_invalid_decimals() {
    let mut state = COMPONENT_STATE();
    let underlying = deploy_erc20_custom_decimals(OWNER, TOKEN_SUPPLY);

    state.initializer(underlying.contract_address);
}

//
// deposit_for
//

#[test]
fn deposit_for_mints_wrapped_and_pulls_underlying() {
    let mut spy = spy_events();
    let (underlying, wrapper) = setup_wrapped();

    // approve wrapper to spend underlying
    start_cheat_caller_address(underlying.contract_address, OWNER);
    assert!(underlying.approve(wrapper.contract_address, VALUE));
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(RECIPIENT, VALUE));

    // underlying moved from owner to wrapper
    assert_eq!(underlying.balance_of(OWNER), TOKEN_SUPPLY - VALUE);
    assert_eq!(underlying.balance_of(wrapper.contract_address), VALUE);

    // wrapped tokens minted to recipient (Transfer event from zero)
    spy.assert_event_transfer(wrapper.contract_address, ZERO, RECIPIENT, VALUE);
    spy.assert_event_deposit(wrapper.contract_address, OWNER, RECIPIENT, VALUE);
}

#[test]
#[should_panic(expected: 'Wrapper: invalid receiver')]
fn deposit_for_reverts_when_receiver_is_wrapper() {
    let (_, wrapper) = setup_wrapped();

    wrapper.deposit_for(wrapper.contract_address, VALUE);
}

#[test]
fn deposit_for_allows_zero_amount() {
    let (underlying, wrapper) = setup_wrapped();
    let wrapper_erc20 = IERC20Dispatcher { contract_address: wrapper.contract_address };

    start_cheat_caller_address(underlying.contract_address, OWNER);
    assert!(underlying.approve(wrapper.contract_address, 0));
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(RECIPIENT, 0));
    stop_cheat_caller_address(wrapper.contract_address);

    assert_eq!(underlying.balance_of(OWNER), TOKEN_SUPPLY);
    assert_eq!(underlying.balance_of(wrapper.contract_address), 0);
    assert_eq!(wrapper_erc20.total_supply(), 0);
    assert_eq!(wrapper_erc20.balance_of(RECIPIENT), 0);
}

#[test]
#[should_panic(expected: 'Wrapper: invalid receiver')]
fn deposit_for_reverts_when_receiver_is_zero() {
    let (underlying, wrapper) = setup_wrapped();

    start_cheat_caller_address(underlying.contract_address, OWNER);
    assert!(underlying.approve(wrapper.contract_address, VALUE));
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    wrapper.deposit_for(ZERO, VALUE);
}

//
// withdraw_to
//

#[test]
fn withdraw_to_burns_wrapped_and_returns_underlying() {
    let mut spy = spy_events();
    let (underlying, wrapper) = setup_wrapped();

    // prepare: deposit first
    start_cheat_caller_address(underlying.contract_address, OWNER);
    assert!(underlying.approve(wrapper.contract_address, VALUE));
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(OWNER, VALUE));

    // withdraw to recipient
    assert!(wrapper.withdraw_to(RECIPIENT, VALUE));

    // wrapped burned from owner (Transfer to zero)
    spy.assert_event_transfer(wrapper.contract_address, OWNER, ZERO, VALUE);
    spy.assert_event_withdraw(wrapper.contract_address, OWNER, RECIPIENT, VALUE);

    // underlying moved out to recipient
    assert_eq!(underlying.balance_of(RECIPIENT), VALUE);
    assert_eq!(underlying.balance_of(wrapper.contract_address), 0);
}

#[test]
#[should_panic(expected: 'Wrapper: invalid receiver')]
fn withdraw_to_reverts_when_receiver_is_wrapper() {
    let (underlying, wrapper) = setup_wrapped();

    start_cheat_caller_address(underlying.contract_address, OWNER);
    underlying.approve(wrapper.contract_address, VALUE);
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    wrapper.deposit_for(OWNER, VALUE);

    wrapper.withdraw_to(wrapper.contract_address, VALUE);
}

#[test]
fn withdraw_to_allows_zero_amount() {
    let (underlying, wrapper) = setup_wrapped();
    let wrapper_erc20 = IERC20Dispatcher { contract_address: wrapper.contract_address };

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.withdraw_to(RECIPIENT, 0));
    stop_cheat_caller_address(wrapper.contract_address);

    assert_eq!(underlying.balance_of(RECIPIENT), 0);
    assert_eq!(underlying.balance_of(wrapper.contract_address), 0);
    assert_eq!(wrapper_erc20.total_supply(), 0);
    assert_eq!(wrapper_erc20.balance_of(OWNER), 0);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn withdraw_to_reverts_when_insufficient_balance() {
    let (_, wrapper) = setup_wrapped();

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    wrapper.withdraw_to(RECIPIENT, VALUE);
}

#[test]
#[should_panic(expected: 'Wrapper: invalid receiver')]
fn withdraw_to_reverts_when_receiver_is_zero() {
    let (underlying, wrapper) = setup_wrapped();

    start_cheat_caller_address(underlying.contract_address, OWNER);
    assert!(underlying.approve(wrapper.contract_address, VALUE));
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(OWNER, VALUE));
    wrapper.withdraw_to(ZERO, VALUE);
}

//
// recover
//

#[test]
fn recover_mints_excess_underlying() {
    let (underlying, wrapper) = setup_wrapped();
    let wrapper_erc20 = IERC20Dispatcher { contract_address: wrapper.contract_address };

    start_cheat_caller_address(underlying.contract_address, OWNER);
    assert!(underlying.transfer(wrapper.contract_address, VALUE));
    stop_cheat_caller_address(underlying.contract_address);

    let recovered = wrapper.recover(RECIPIENT);
    assert_eq!(recovered, VALUE);
    assert_eq!(wrapper_erc20.total_supply(), VALUE);
    assert_eq!(wrapper_erc20.balance_of(RECIPIENT), VALUE);
}

#[test]
#[should_panic(expected: 'Wrapper: nothing to recover')]
fn recover_reverts_when_no_excess_underlying() {
    let (underlying, wrapper) = setup_wrapped();

    start_cheat_caller_address(underlying.contract_address, OWNER);
    assert!(underlying.approve(wrapper.contract_address, VALUE));
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(OWNER, VALUE));
    stop_cheat_caller_address(wrapper.contract_address);

    wrapper.recover(RECIPIENT);
}

#[test]
#[should_panic]
fn recover_reverts_when_underlying_below_total_supply() {
    let (underlying, wrapper) = setup_wrapped();

    start_cheat_caller_address(underlying.contract_address, OWNER);
    assert!(underlying.approve(wrapper.contract_address, VALUE));
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(OWNER, VALUE));
    stop_cheat_caller_address(wrapper.contract_address);

    start_cheat_caller_address(underlying.contract_address, wrapper.contract_address);
    assert!(underlying.transfer(OWNER, VALUE));
    stop_cheat_caller_address(underlying.contract_address);

    wrapper.recover(RECIPIENT);
}

//
// Spy helpers
//

#[generate_trait]
pub impl ERC20WrapperSpyHelpersImpl of ERC20WrapperSpyHelpers {
    fn assert_event_deposit(
        ref self: EventSpy,
        contract: ContractAddress,
        sender: ContractAddress,
        receiver: ContractAddress,
        assets: u256,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("Deposit"))
            .key(sender)
            .key(receiver)
            .data(assets);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_withdraw(
        ref self: EventSpy,
        contract: ContractAddress,
        caller: ContractAddress,
        receiver: ContractAddress,
        assets: u256,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("Withdraw"))
            .key(caller)
            .key(receiver)
            .data(assets);
        self.assert_emitted_single(contract, expected);
    }
}
