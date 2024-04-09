use integer::BoundedInt;
use openzeppelin::access::ownable::OwnableComponent::OwnershipTransferred;
use openzeppelin::presets::ERC20Upgradeable;
use openzeppelin::presets::interfaces::{
    IERC20UpgradeableDispatcher, IERC20UpgradeableDispatcherTrait
};
use openzeppelin::tests::access::test_ownable::assert_event_ownership_transferred;
use openzeppelin::tests::mocks::erc20_mocks::SnakeERC20Mock;
use openzeppelin::tests::token::test_erc20::{
    assert_event_approval, assert_only_event_approval, assert_only_event_transfer
};
use openzeppelin::tests::upgrades::test_upgradeable::assert_only_event_upgraded;
use openzeppelin::tests::utils::constants::{
    ZERO, OWNER, SPENDER, RECIPIENT, OTHER, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE, CLASS_HASH_ZERO
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ClassHash;
use starknet::testing;

fn V2_CLASS_HASH() -> ClassHash {
    SnakeERC20Mock::TEST_CLASS_HASH.try_into().unwrap()
}

//
// Setup
//

fn setup_dispatcher_with_event() -> IERC20UpgradeableDispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(SUPPLY);
    calldata.append_serde(OWNER());
    calldata.append_serde(OWNER());

    let address = utils::deploy(ERC20Upgradeable::TEST_CLASS_HASH, calldata);
    IERC20UpgradeableDispatcher { contract_address: address }
}

fn setup_dispatcher() -> IERC20UpgradeableDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    utils::drop_event(dispatcher.contract_address); // Ownable `OwnershipTransferred`
    utils::drop_event(dispatcher.contract_address); // ERC20 `Transfer`
    dispatcher
}

//
// constructor
//

#[test]
fn test_constructor() {
    let mut dispatcher = setup_dispatcher_with_event();

    assert_eq!(dispatcher.owner(), OWNER());
    assert_event_ownership_transferred(dispatcher.contract_address, ZERO(), OWNER());

    assert_eq!(dispatcher.name(), NAME());
    assert_eq!(dispatcher.symbol(), SYMBOL());
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
// transfer_ownership & transferOwnership
//

#[test]
fn test_transfer_ownership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transfer_ownership(OTHER());

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), OTHER());
    assert_eq!(dispatcher.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_to_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transfer_ownership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_from_zero() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.transfer_ownership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transfer_ownership(OTHER());
}

#[test]
fn test_transferOwnership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transferOwnership(OTHER());

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), OTHER());
    assert_eq!(dispatcher.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_to_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transferOwnership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_from_zero() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.transferOwnership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transferOwnership(OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
fn test_renounce_ownership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.renounce_ownership();

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), ZERO());
    assert!(dispatcher.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_renounce_ownership_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.renounce_ownership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_renounce_ownership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.renounce_ownership();
}

#[test]
fn test_renounceOwnership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.renounceOwnership();

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), ZERO());
    assert!(dispatcher.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_renounceOwnership_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    dispatcher.renounceOwnership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_renounceOwnership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.renounceOwnership();
}

//
// upgrade
//

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_unauthorized() {
    let v1 = setup_dispatcher();
    testing::set_contract_address(OTHER());
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_with_class_hash_zero() {
    let v1 = setup_dispatcher();

    testing::set_contract_address(OWNER());
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
fn test_upgraded_event() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.upgrade(v2_class_hash);

    assert_only_event_upgraded(v1.contract_address, v2_class_hash);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_v2_missing_camel_selector() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.upgrade(v2_class_hash);

    let dispatcher = IERC20CamelDispatcher { contract_address: v1.contract_address };
    dispatcher.totalSupply();
}

#[test]
fn test_state_persists_after_upgrade() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.transfer(RECIPIENT(), VALUE);

    // Check RECIPIENT balance v1
    let camel_balance = v1.balanceOf(RECIPIENT());
    assert_eq!(camel_balance, VALUE);

    v1.upgrade(v2_class_hash);

    // Check RECIPIENT balance v2
    let v2 = IERC20Dispatcher { contract_address: v1.contract_address };
    let snake_balance = v2.balance_of(RECIPIENT());
    assert_eq!(snake_balance, camel_balance);
}
