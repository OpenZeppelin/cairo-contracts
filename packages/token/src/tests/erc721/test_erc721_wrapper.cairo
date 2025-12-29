use openzeppelin_interfaces::erc721::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721ReceiverDispatcher,
    IERC721ReceiverDispatcherTrait, IERC721_RECEIVER_ID,
};
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_interfaces::token::erc721::{
    IERC721WrapperDispatcher, IERC721WrapperDispatcherTrait,
};
use openzeppelin_test_common::erc721::ERC721SpyHelpers;
use openzeppelin_test_common::mocks::erc721::{
    ERC721WrapperMock, IERC721MintableDispatcher, IERC721MintableDispatcherTrait,
    IERC721WrapperRecovererDispatcher,
    IERC721WrapperRecovererDispatcherTrait,
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{
    AsAddressTrait, BASE_URI, EMPTY_DATA, NAME, OTHER, OWNER, RECIPIENT, SYMBOL, TOKEN_ID,
    TOKEN_ID_2, ZERO,
};
use openzeppelin_testing::spy_events;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address, test_address};
use starknet::ContractAddress;
use crate::erc721::extensions::erc721_wrapper::ERC721WrapperComponent;
use crate::erc721::extensions::erc721_wrapper::ERC721WrapperComponent::{
    ERC721WrapperImpl, InternalImpl as WrapperInternalImpl,
};

const UNDERLYING: ContractAddress = 'UNDERLYING'.as_address();

type ComponentState =
    ERC721WrapperComponent::ComponentState<ERC721WrapperMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC721WrapperComponent::component_state_for_testing()
}

//
// Setup
//

fn deploy_underlying() -> IERC721Dispatcher {
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());

    let contract_address = utils::declare_and_deploy("ERC721MintableMock", calldata);
    IERC721Dispatcher { contract_address }
}

fn deploy_wrapper(underlying: ContractAddress) -> IERC721WrapperDispatcher {
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(underlying);

    let contract_address = utils::declare_and_deploy("ERC721WrapperMock", calldata);
    IERC721WrapperDispatcher { contract_address }
}

fn setup_wrapped() -> (IERC721Dispatcher, IERC721WrapperDispatcher) {
    let underlying = deploy_underlying();
    let wrapper = deploy_wrapper(underlying.contract_address);
    (underlying, wrapper)
}

fn mint_underlying(underlying: ContractAddress, owner: ContractAddress, token_id: u256) {
    let minter = IERC721MintableDispatcher { contract_address: underlying };
    minter.mint(owner, token_id);
}

fn recover_dispatcher(address: ContractAddress) -> IERC721WrapperRecovererDispatcher {
    IERC721WrapperRecovererDispatcher { contract_address: address }
}

//
// initializer
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = ERC721WrapperMock::contract_state_for_testing();

    state.initializer(UNDERLYING);
    assert_eq!(state.underlying(), UNDERLYING);

    let supports_receiver = mock_state.supports_interface(IERC721_RECEIVER_ID);
    assert!(supports_receiver);

    let supports_isrc5 = mock_state.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);
}

#[test]
#[should_panic(expected: 'ERC721Wrapper: invalid underlying')]
fn initializer_reverts_on_zero_underlying() {
    let mut state = COMPONENT_STATE();
    state.initializer(ZERO);
}

#[test]
#[should_panic(expected: 'ERC721Wrapper: invalid underlying')]
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
    let wrapper_erc721 = IERC721Dispatcher { contract_address: wrapper.contract_address };

    mint_underlying(underlying.contract_address, OWNER, TOKEN_ID);

    start_cheat_caller_address(underlying.contract_address, OWNER);
    underlying.approve(wrapper.contract_address, TOKEN_ID);
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(RECIPIENT, array![TOKEN_ID].span()));
    stop_cheat_caller_address(wrapper.contract_address);

    assert_eq!(underlying.owner_of(TOKEN_ID), wrapper.contract_address);
    assert_eq!(wrapper_erc721.owner_of(TOKEN_ID), RECIPIENT);
    spy.assert_event_transfer(wrapper.contract_address, ZERO, RECIPIENT, TOKEN_ID);
}

#[test]
fn deposit_for_handles_multiple_tokens() {
    let (underlying, wrapper) = setup_wrapped();
    let wrapper_erc721 = IERC721Dispatcher { contract_address: wrapper.contract_address };

    mint_underlying(underlying.contract_address, OWNER, TOKEN_ID);
    mint_underlying(underlying.contract_address, OWNER, TOKEN_ID_2);

    start_cheat_caller_address(underlying.contract_address, OWNER);
    underlying.approve(wrapper.contract_address, TOKEN_ID);
    underlying.approve(wrapper.contract_address, TOKEN_ID_2);
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(RECIPIENT, array![TOKEN_ID, TOKEN_ID_2].span()));
    stop_cheat_caller_address(wrapper.contract_address);

    assert_eq!(underlying.owner_of(TOKEN_ID), wrapper.contract_address);
    assert_eq!(underlying.owner_of(TOKEN_ID_2), wrapper.contract_address);
    assert_eq!(wrapper_erc721.owner_of(TOKEN_ID), RECIPIENT);
    assert_eq!(wrapper_erc721.owner_of(TOKEN_ID_2), RECIPIENT);
    assert_eq!(wrapper_erc721.balance_of(RECIPIENT), 2);
}

//
// withdraw_to
//

#[test]
fn withdraw_to_burns_wrapped_and_returns_underlying() {
    let mut spy = spy_events();
    let (underlying, wrapper) = setup_wrapped();
    let wrapper_erc721 = IERC721Dispatcher { contract_address: wrapper.contract_address };

    mint_underlying(underlying.contract_address, OWNER, TOKEN_ID);

    start_cheat_caller_address(underlying.contract_address, OWNER);
    underlying.approve(wrapper.contract_address, TOKEN_ID);
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(OWNER, array![TOKEN_ID].span()));
    assert!(wrapper.withdraw_to(RECIPIENT, array![TOKEN_ID].span()));
    stop_cheat_caller_address(wrapper.contract_address);

    assert_eq!(underlying.owner_of(TOKEN_ID), RECIPIENT);
    assert_eq!(wrapper_erc721.balance_of(OWNER), 0);
    spy.assert_event_transfer(wrapper.contract_address, OWNER, ZERO, TOKEN_ID);
}

#[test]
#[should_panic(expected: 'ERC721: unauthorized caller')]
fn withdraw_to_reverts_for_unauthorized_caller() {
    let (underlying, wrapper) = setup_wrapped();

    mint_underlying(underlying.contract_address, OWNER, TOKEN_ID);

    start_cheat_caller_address(underlying.contract_address, OWNER);
    underlying.approve(wrapper.contract_address, TOKEN_ID);
    stop_cheat_caller_address(underlying.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OWNER);
    assert!(wrapper.deposit_for(OWNER, array![TOKEN_ID].span()));
    stop_cheat_caller_address(wrapper.contract_address);

    start_cheat_caller_address(wrapper.contract_address, OTHER);
    wrapper.withdraw_to(RECIPIENT, array![TOKEN_ID].span());
}

//
// on_erc721_received
//

#[test]
fn on_erc721_received_mints_wrapped_on_safe_transfer() {
    let mut spy = spy_events();
    let (underlying, wrapper) = setup_wrapped();
    let wrapper_erc721 = IERC721Dispatcher { contract_address: wrapper.contract_address };

    mint_underlying(underlying.contract_address, OWNER, TOKEN_ID);

    start_cheat_caller_address(underlying.contract_address, OWNER);
    underlying.safe_transfer_from(OWNER, wrapper.contract_address, TOKEN_ID, EMPTY_DATA());
    stop_cheat_caller_address(underlying.contract_address);

    assert_eq!(underlying.owner_of(TOKEN_ID), wrapper.contract_address);
    assert_eq!(wrapper_erc721.owner_of(TOKEN_ID), OWNER);
    spy.assert_event_transfer(wrapper.contract_address, ZERO, OWNER, TOKEN_ID);
}

#[test]
#[should_panic(expected: 'ERC721Wrapper: unsupported token')]
fn on_erc721_received_reverts_for_unsupported_token() {
    let (_, wrapper) = setup_wrapped();
    let receiver = IERC721ReceiverDispatcher { contract_address: wrapper.contract_address };

    start_cheat_caller_address(wrapper.contract_address, OTHER);
    receiver.on_erc721_received(OTHER, OWNER, TOKEN_ID, EMPTY_DATA());
}

//
// recover
//

#[test]
fn recover_mints_wrapped_for_untracked_underlying() {
    let (underlying, wrapper) = setup_wrapped();
    let wrapper_erc721 = IERC721Dispatcher { contract_address: wrapper.contract_address };
    let recoverer = recover_dispatcher(wrapper.contract_address);

    mint_underlying(underlying.contract_address, OWNER, TOKEN_ID);

    start_cheat_caller_address(underlying.contract_address, OWNER);
    underlying.transfer_from(OWNER, wrapper.contract_address, TOKEN_ID);
    stop_cheat_caller_address(underlying.contract_address);

    let recovered = recoverer.recover(RECIPIENT, TOKEN_ID);
    assert_eq!(recovered, TOKEN_ID);
    assert_eq!(underlying.owner_of(TOKEN_ID), wrapper.contract_address);
    assert_eq!(wrapper_erc721.owner_of(TOKEN_ID), RECIPIENT);
}

#[test]
#[should_panic(expected: 'ERC721Wrapper: incorrect owner')]
fn recover_reverts_when_underlying_not_owned() {
    let (_, wrapper) = setup_wrapped();
    let recoverer = recover_dispatcher(wrapper.contract_address);

    recoverer.recover(RECIPIENT, TOKEN_ID);
}
