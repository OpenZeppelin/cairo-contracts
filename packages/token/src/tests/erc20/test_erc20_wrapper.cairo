use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_interfaces::token::erc20::{
    IERC20Wrapper, IERC20WrapperDispatcher, IERC20WrapperDispatcherTrait,
};
use openzeppelin_test_common::erc20::{ERC20SpyHelpers, deploy_erc20};
use openzeppelin_test_common::mocks::erc20::ERC20WrapperMock;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{AsAddressTrait, NAME, OWNER, RECIPIENT, SYMBOL, VALUE, ZERO};
use openzeppelin_testing::spy_events;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address, test_address};
use starknet::ContractAddress;
use crate::erc20::ERC20Component::{ERC20Impl, InternalImpl as ERC20InternalImpl};
use crate::erc20::extensions::erc20_wrapper::ERC20WrapperComponent;
use crate::erc20::extensions::erc20_wrapper::ERC20WrapperComponent::{
    ERC20WrapperImpl, InternalImpl as WrapperInternalImpl,
};

const TOKEN_SUPPLY: u256 = VALUE * 10;
const UNDERLYING: ContractAddress = 'UNDERLYING'.as_address();

type ComponentState = ERC20WrapperComponent::ComponentState<ERC20WrapperMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC20WrapperComponent::component_state_for_testing()
}

//
// Setup
//

fn deploy_wrapper(underlying: ContractAddress) -> IERC20WrapperDispatcher {
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(underlying);

    let contract_address = utils::declare_and_deploy("ERC20WrapperMock", calldata);
    IERC20WrapperDispatcher { contract_address }
}

fn setup_wrapped() -> (IERC20Dispatcher, IERC20WrapperDispatcher) {
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
    state.initializer(UNDERLYING);

    assert_eq!(state.underlying(), UNDERLYING);
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
}

#[test]
#[should_panic(expected: 'Wrapper: invalid receiver')]
fn deposit_for_reverts_when_receiver_is_wrapper() {
    let (_, wrapper) = setup_wrapped();

    wrapper.deposit_for(wrapper.contract_address, VALUE);
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
