use integer::BoundedInt;
use openzeppelin::presets::ERC20Votes;
use openzeppelin::tests::token::test_erc20::{
    assert_only_event_transfer, assert_only_event_approval, assert_event_approval
};
use openzeppelin::tests::token::test_erc20_votes::{
    assert_event_delegate_changed, assert_only_event_delegate_changed,
    assert_event_delegate_votes_changed, assert_only_event_delegate_votes_changed
};
use openzeppelin::tests::utils::constants::{
    DAPP_NAME, DAPP_VERSION, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE, ZERO, OWNER, SPENDER, RECIPIENT
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{ERC20VotesABIDispatcher, ERC20VotesABIDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::structs::checkpoint::Checkpoint;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;

//
// Setup
//

fn setup_dispatcher_with_event() -> ERC20VotesABIDispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(SUPPLY);
    calldata.append_serde(OWNER());

    testing::set_block_timestamp('ts0');
    let address = utils::deploy(ERC20Votes::TEST_CLASS_HASH, calldata);
    ERC20VotesABIDispatcher { contract_address: address }
}

fn setup_dispatcher() -> ERC20VotesABIDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    utils::drop_event(dispatcher.contract_address);
    dispatcher
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut dispatcher = setup_dispatcher_with_event();

    assert_only_event_transfer(ZERO(), OWNER(), SUPPLY);
    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY);
    assert_eq!(dispatcher.total_supply(), SUPPLY);
    assert_eq!(dispatcher.name(), NAME());
    assert_eq!(dispatcher.symbol(), SYMBOL());
    assert_eq!(dispatcher.decimals(), DECIMALS);
}

//
// Getters
//

#[test]
#[available_gas(2000000)]
fn test_total_supply() {
    let dispatcher = setup_dispatcher();
    assert_eq!(dispatcher.total_supply(), SUPPLY);
}

#[test]
fn test_balance_of() {
    let dispatcher = setup_dispatcher();

    testing::set_caller_address(OWNER());
    dispatcher.transfer(RECIPIENT(), SUPPLY);
    assert_eq!(dispatcher.balance_of(RECIPIENT()), SUPPLY);
}

#[test]
#[available_gas(2000000)]
fn test_allowance() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);

    assert_eq!(dispatcher.allowance(OWNER(), SPENDER()), VALUE);
}

//
// approve
//

#[test]
fn test_approve() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    assert!(dispatcher.approve(SPENDER(), VALUE));
    assert_only_event_approval(OWNER(), SPENDER(), VALUE);

    assert_eq!(dispatcher.allowance(OWNER(), SPENDER()), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0',))]
fn test_approve_from_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.approve(SPENDER(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0',))]
fn test_approve_to_zero() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.approve(Zeroable::zero(), VALUE);
}

//
// transfer
//

#[test]
fn test_transfer() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    assert!(dispatcher.transfer(RECIPIENT(), VALUE));
    assert_only_event_transfer(OWNER(), RECIPIENT(), VALUE);

    assert_eq!(dispatcher.balance_of(RECIPIENT()), VALUE);
    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY - VALUE);
    assert_eq!(dispatcher.total_supply(), SUPPLY);
}

//
// transfer_from
//

#[test]
fn test_transfer_from() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);
    utils::drop_event(ZERO());

    testing::set_caller_address(SPENDER());
    assert!(dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE));

    assert_event_approval(OWNER(), SPENDER(), 0);
    assert_only_event_transfer(OWNER(), RECIPIENT(), VALUE);

    assert_eq!(dispatcher.balance_of(RECIPIENT()), VALUE);
    assert_eq!(dispatcher.balance_of(OWNER()), SUPPLY - VALUE);
    assert!(dispatcher.allowance(OWNER(), SPENDER()).is_zero());
    assert_eq!(dispatcher.total_supply(), SUPPLY);
}

#[test]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.approve(SPENDER(), BoundedInt::max());

    testing::set_caller_address(SPENDER());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);

    assert_eq!(
        dispatcher.allowance(OWNER(), SPENDER()), BoundedInt::max(), "Allowance should not change"
    );
}

#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_transfer_from_greater_than_allowance() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    dispatcher.transfer_from(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test_transfer_from_to_zero_address() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.approve(SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    dispatcher.transfer_from(OWNER(), Zeroable::zero(), VALUE);
}

#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_transfer_from_from_zero_address() {
    let dispatcher = setup_dispatcher();
    dispatcher.transfer_from(Zeroable::zero(), RECIPIENT(), VALUE);
}

//
// get_votes && get_past_votes
//

#[test]
fn test_get_votes() {
    let mut dispatcher = setup_dispatcher();

    testing::set_caller_address(OWNER());
    dispatcher.delegate(OWNER());

    assert_eq!(dispatcher.get_votes(OWNER()), SUPPLY);
}

#[test]
fn test_get_past_votes() {
    let mut dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.delegate(OWNER());
    let amount = 100;

    testing::set_block_timestamp('ts1');
    dispatcher.transfer(RECIPIENT(), amount);
    testing::set_block_timestamp('ts2');
    dispatcher.transfer(RECIPIENT(), amount);
    testing::set_block_timestamp('ts4');
    dispatcher.transfer(RECIPIENT(), amount);

    assert_eq!(dispatcher.get_past_votes(OWNER(), 'ts1'), SUPPLY - amount, "Should match ts1");
    assert_eq!(dispatcher.get_past_votes(OWNER(), 'ts3'), SUPPLY - 2 * amount, "Should match ts2");
}

#[test]
#[should_panic(expected: ('Votes: future Lookup',))]
fn test_get_past_votes_future_lookup() {
    let dispatcher = setup_dispatcher();

    // Past timestamp.
    testing::set_block_timestamp('ts1');
    dispatcher.get_past_votes(OWNER(), 'ts2');
}

#[test]
fn test_get_past_total_supply() {
    let mut dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.delegate(OWNER());
    let amount = 100;

    // This should not affect total_supply checkpoints
    testing::set_block_timestamp('ts1');
    dispatcher.transfer(RECIPIENT(), amount);
    testing::set_block_timestamp('ts4');

    // ts0 is the timestamp at construction time, when the tokens were minted
    assert_eq!(dispatcher.get_past_total_supply('ts3'), SUPPLY, "Should eq ts0");
}

#[test]
#[should_panic(expected: ('Votes: future Lookup',))]
fn test_get_past_total_supply_future_lookup() {
    let dispatcher = setup_dispatcher();

    // Past timestamp.
    testing::set_block_timestamp('ts1');
    dispatcher.get_past_total_supply('ts2');
}

//
// delegate & delegates
//

#[test]
fn test_delegate() {
    let mut dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());

    // Delegate from zero
    dispatcher.delegate(OWNER());

    assert_event_delegate_changed(OWNER(), ZERO(), OWNER());
    assert_only_event_delegate_votes_changed(OWNER(), 0, SUPPLY);
    assert_eq!(dispatcher.get_votes(OWNER()), SUPPLY);

    // Delegate from non-zero to non-zero
    dispatcher.delegate(RECIPIENT());

    assert_event_delegate_changed(OWNER(), OWNER(), RECIPIENT());
    assert_event_delegate_votes_changed(OWNER(), SUPPLY, 0);
    assert_only_event_delegate_votes_changed(RECIPIENT(), 0, SUPPLY);
    assert!(dispatcher.get_votes(OWNER()).is_zero());
    assert_eq!(dispatcher.get_votes(RECIPIENT()), SUPPLY);

    // Delegate to zero
    dispatcher.delegate(ZERO());

    assert_event_delegate_changed(OWNER(), RECIPIENT(), ZERO());
    assert_event_delegate_votes_changed(RECIPIENT(), SUPPLY, 0);
    assert!(dispatcher.get_votes(RECIPIENT()).is_zero());

    // Delegate from zero to zero
    dispatcher.delegate(ZERO());

    assert_only_event_delegate_changed(OWNER(), ZERO(), ZERO());
}

#[test]
fn test_delegates() {
    let mut dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());

    dispatcher.delegate(OWNER());
    assert_eq!(dispatcher.delegates(OWNER()), OWNER());

    dispatcher.delegate(RECIPIENT());
    assert_eq!(dispatcher.delegates(OWNER()), RECIPIENT());
}

//
// num_checkpoints & checkpoints
//

#[test]
fn test_num_checkpoints() {
    let mut dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.delegate(OWNER());

    let amount = 100;
    testing::set_block_timestamp('ts1');
    dispatcher.transfer(RECIPIENT(), amount);
    testing::set_block_timestamp('ts2');
    dispatcher.transfer(RECIPIENT(), amount);
    testing::set_block_timestamp('ts4');
    dispatcher.transfer(RECIPIENT(), amount);

    // Delagating to self should increase the number of checkpoints
    assert_eq!(dispatcher.num_checkpoints(OWNER()), 4);

    testing::set_block_timestamp('ts5');
    dispatcher.transfer(RECIPIENT(), amount);
    testing::set_block_timestamp('ts7');
    dispatcher.transfer(RECIPIENT(), amount);
    assert_eq!(dispatcher.num_checkpoints(OWNER()), 6);

    assert!(dispatcher.num_checkpoints(RECIPIENT()).is_zero());
}

#[test]
fn test_checkpoints() {
    let dispatcher = setup_dispatcher();
    testing::set_caller_address(OWNER());
    dispatcher.delegate(OWNER());

    let amount = 100;
    testing::set_block_timestamp('ts1');
    dispatcher.transfer(RECIPIENT(), amount);
    testing::set_block_timestamp('ts2');
    dispatcher.transfer(RECIPIENT(), amount);
    testing::set_block_timestamp('ts4');
    dispatcher.transfer(RECIPIENT(), amount);

    let checkpoint: Checkpoint = dispatcher.checkpoints(OWNER(), 2);
    assert_eq!(checkpoint.key, 'ts2');
    assert_eq!(checkpoint.value, SUPPLY - 2 * amount);
}

#[test]
#[should_panic(expected: ('Array overflow',))]
fn test_checkpoints_array_overflow() {
    let dispatcher = setup_dispatcher();

    dispatcher.checkpoints(OWNER(), 1);
}

