use integer::BoundedInt;
use openzeppelin::presets::ERC20;
use openzeppelin::tests::utils::constants::{
    ZERO, OWNER, SPENDER, RECIPIENT, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE
};
use openzeppelin::tests::utils::debug::DebugContractAddress;
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::ERC20Component::{Approval, Transfer};
use openzeppelin::token::erc20::ERC20Component::{ERC20CamelOnlyImpl, ERC20Impl};
use openzeppelin::token::erc20::ERC20Component::{ERC20MetadataImpl, InternalImpl};
use openzeppelin::token::erc20::ERC20Component::{SafeAllowanceImpl, SafeAllowanceCamelImpl};
use openzeppelin::token::erc20::interface::ERC20ABI;
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::testing;

//
// Setup
//

fn setup_dispatcher_with_event() -> ERC20ABIDispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME);
    calldata.append_serde(SYMBOL);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(OWNER());

    let address = utils::deploy(ERC20::TEST_CLASS_HASH, calldata);
    ERC20ABIDispatcher { contract_address: address }
}

fn setup_dispatcher() -> ERC20ABIDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    utils::drop_event(dispatcher.contract_address);
    dispatcher
}

//
// constructor
//

#[test]
fn test_constructor() {
    let mut dispatcher = setup_dispatcher_with_event();

    assert_eq!(dispatcher.name(), NAME);
    assert_eq!(dispatcher.symbol(), SYMBOL);
    assert_eq!(dispatcher.decimals(), DECIMALS);
    assert_eq!(dispatcher.total_supply(), SUPPLY);
    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY);
    assert_only_event_transfer(dispatcher.contract_address, ZERO(), OWNER(), SUPPLY);
}

//
// Getters
//

#[test]
fn test_total_supply() {
    let mut dispatcher = setup_dispatcher();

    assert_eq!(dispatcher.total_supply(), SUPPLY);
    assert_eq!(dispatcher.totalSupply(), SUPPLY);
}

#[test]
fn test_balance_of() {
    let mut dispatcher = setup_dispatcher();

    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY);
    assert_eq!(dispatcher.balanceOf(OWNER()), SUPPLY);
}

#[test]
fn test_allowance() {
    let mut dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);

    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, VALUE);
}

//
// approve
//

#[test]
fn test_approve() {
    let mut dispatcher = setup_dispatcher();
    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert!(allowance.is_zero());

    testing::set_contract_address(OWNER());
    assert!(dispatcher.approve(SPENDER(), VALUE));

    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, VALUE);

    assert_only_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: approve from 0', 'ENTRYPOINT_FAILED'))]
fn test_approve_from_zero() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.approve(SPENDER(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: approve to 0', 'ENTRYPOINT_FAILED'))]
fn test_approve_to_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(Zeroable::zero(), VALUE);
}

//
// transfer
//

#[test]
fn test_transfer() {
    let mut dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    assert!(dispatcher.transfer(RECIPIENT(), VALUE));

    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY - VALUE);
    assert_eq!(dispatcher.balance_of(RECIPIENT()), VALUE);
    assert_eq!(dispatcher.total_supply(), SUPPLY);

    assert_only_event_transfer(dispatcher.contract_address, OWNER(), RECIPIENT(), VALUE);
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_transfer_not_enough_balance() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());

    let balance_plus_one = SUPPLY + 1;
    dispatcher.transfer(RECIPIENT(), balance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC20: transfer from 0', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_zero() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.transfer(RECIPIENT(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: transfer to 0', 'ENTRYPOINT_FAILED'))]
fn test_transfer_to_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transfer(ZERO(), VALUE);
}

//
// transfer_from & transferFrom
//

#[test]
fn test_transfer_from() {
    let mut dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(SPENDER());
    assert!(dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE));

    assert_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), 0);
    assert_only_event_transfer(dispatcher.contract_address, OWNER(), RECIPIENT(), VALUE);

    assert_eq!(dispatcher.balance_of(RECIPIENT()), VALUE);
    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY - VALUE);
    assert_eq!(dispatcher.allowance(OWNER(), SPENDER()), 0);
    assert_eq!(dispatcher.total_supply(), SUPPLY);
}

#[test]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    let mut dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), BoundedInt::max());

    testing::set_contract_address(SPENDER());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);

    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, BoundedInt::max(), "Should not decrease");
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_greater_than_allowance() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);

    testing::set_contract_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    dispatcher.transfer_from(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC20: transfer to 0', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_to_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);

    testing::set_contract_address(SPENDER());
    dispatcher.transfer_from(OWNER(), Zeroable::zero(), VALUE);
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.transfer_from(Zeroable::zero(), RECIPIENT(), VALUE);
}

#[test]
fn test_transferFrom() {
    let mut dispatcher = setup_dispatcher();

    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(SPENDER());
    assert!(dispatcher.transferFrom(OWNER(), RECIPIENT(), VALUE));

    assert_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), 0);
    assert_only_event_transfer(dispatcher.contract_address, OWNER(), RECIPIENT(), VALUE);

    assert_eq!(dispatcher.balance_of(RECIPIENT()), VALUE);
    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY - VALUE);
    assert_eq!(dispatcher.allowance(OWNER(), SPENDER()), 0);
    assert_eq!(dispatcher.total_supply(), SUPPLY);
}

#[test]
fn test_transferFrom_doesnt_consume_infinite_allowance() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), BoundedInt::max());

    testing::set_contract_address(SPENDER());
    dispatcher.transferFrom(OWNER(), RECIPIENT(), VALUE);

    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, BoundedInt::max(), "Should not decrease");
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_greater_than_allowance() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);

    testing::set_contract_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    dispatcher.transferFrom(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC20: transfer to 0', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_to_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);

    testing::set_contract_address(SPENDER());
    dispatcher.transferFrom(OWNER(), Zeroable::zero(), VALUE);
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.transferFrom(Zeroable::zero(), RECIPIENT(), VALUE);
}

//
// increase_allowance & increaseAllowance
//

#[test]
fn test_increase_allowance() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);
    utils::drop_event(dispatcher.contract_address);

    assert!(dispatcher.increase_allowance(SPENDER(), VALUE));

    assert_only_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), VALUE * 2);

    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, VALUE * 2);
}

#[test]
#[should_panic(expected: ('ERC20: approve to 0', 'ENTRYPOINT_FAILED'))]
fn test_increase_allowance_to_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.increase_allowance(Zeroable::zero(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: approve from 0', 'ENTRYPOINT_FAILED'))]
fn test_increase_allowance_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.increase_allowance(SPENDER(), VALUE);
}

#[test]
fn test_increaseAllowance() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);
    utils::drop_event(dispatcher.contract_address);

    assert!(dispatcher.increaseAllowance(SPENDER(), VALUE));

    assert_only_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), 2 * VALUE);

    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, VALUE * 2);
}

#[test]
#[should_panic(expected: ('ERC20: approve to 0', 'ENTRYPOINT_FAILED'))]
fn test_increaseAllowance_to_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.increaseAllowance(Zeroable::zero(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: approve from 0', 'ENTRYPOINT_FAILED'))]
fn test_increaseAllowance_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.increaseAllowance(SPENDER(), VALUE);
}

//
// decrease_allowance & decreaseAllowance
//

#[test]
fn test_decrease_allowance() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);
    utils::drop_event(dispatcher.contract_address);

    assert!(dispatcher.decrease_allowance(SPENDER(), VALUE));

    assert_only_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), 0);

    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert!(allowance.is_zero());
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_decrease_allowance_to_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.decrease_allowance(Zeroable::zero(), VALUE);
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_decrease_allowance_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.decrease_allowance(SPENDER(), VALUE);
}

#[test]
fn test_decreaseAllowance() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);
    utils::drop_event(dispatcher.contract_address);

    assert!(dispatcher.decreaseAllowance(SPENDER(), VALUE));

    assert_only_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), 0);

    let allowance = dispatcher.allowance(OWNER(), SPENDER());
    assert!(allowance.is_zero());
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_decreaseAllowance_to_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.decreaseAllowance(Zeroable::zero(), VALUE);
}

#[test]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED'))]
fn test_decreaseAllowance_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.decreaseAllowance(SPENDER(), VALUE);
}

//
// Helpers
//

fn assert_event_approval(
    contract: ContractAddress, owner: ContractAddress, spender: ContractAddress, value: u256
) {
    let event = utils::pop_log::<Approval>(contract, selector!("Approval")).unwrap();
    assert_eq!(event.owner, owner);
    assert_eq!(event.spender, spender);
    assert_eq!(event.value, value);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(spender);
    utils::assert_indexed_keys(event, indexed_keys.span())
}

fn assert_only_event_approval(
    contract: ContractAddress, owner: ContractAddress, spender: ContractAddress, value: u256
) {
    assert_event_approval(contract, owner, spender, value);
    utils::assert_no_events_left(contract);
}

fn assert_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, value: u256
) {
    let event = utils::pop_log::<Transfer>(contract, selector!("Transfer")).unwrap();
    assert_eq!(event.from, from);
    assert_eq!(event.to, to);
    assert_eq!(event.value, value);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_transfer(
    contract: ContractAddress, from: ContractAddress, to: ContractAddress, value: u256
) {
    assert_event_transfer(contract, from, to, value);
    utils::assert_no_events_left(contract);
}
