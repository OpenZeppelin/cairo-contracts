use core::integer::BoundedInt;
use core::starknet::{ContractAddress, testing};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::mocks::erc6909_mocks::DualCaseERC6909Mock;
use openzeppelin::tests::utils::constants::{
    ZERO, OWNER, SPENDER, RECIPIENT, SUPPLY, VALUE, OPERATOR
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc6909::ERC6909Component::{
    InternalImpl, ERC6909Impl, ERC6909CamelOnlyImpl
};
use openzeppelin::token::erc6909::ERC6909Component::{Approval, Transfer, OperatorSet};
use openzeppelin::token::erc6909::ERC6909Component;
use super::common::{
    assert_event_approval, assert_only_event_approval, assert_only_event_transfer,
    assert_only_event_operator_set, assert_event_operator_set
};

//
// Setup
//

const TOKEN_ID: u256 = 420;

type ComponentState = ERC6909Component::ComponentState<DualCaseERC6909Mock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC6909Component::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, SUPPLY);
    utils::drop_event(ZERO());
    state
}

//
// Getters
//

#[test]
fn test_balance_of() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, SUPPLY);
    assert_eq!(state.balance_of((OWNER()), TOKEN_ID), SUPPLY);
}

#[test]
fn test_balanceOf() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, SUPPLY);
    assert_eq!(state.balanceOf((OWNER()), TOKEN_ID), SUPPLY);
}

#[test]
fn test_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);
    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, VALUE);
}

#[test]
fn test_set_supports_interface() {
    let mut state = setup();
    // IERC6909_ID as defined in `interface.cairo` = 0x32cb2c2fe3eafecaa713aaa072ee54795f66abbd45618bd0ff07284d97116ee
    assert!(
        state.supports_interface(0x32cb2c2fe3eafecaa713aaa072ee54795f66abbd45618bd0ff07284d97116ee)
    );
    assert_eq!(state.supports_interface(0x32cb), false);
    assert_eq!(
        state.supports_interface(0x32cb2c2fe3eafecaa713aaa072ee54795f66abbd45618bd0ff07284d97116ef),
        false
    );

    // id == ISRC5_ID || id == IERC6909_ID
    assert!(state.supports_interface(ISRC5_ID))
}

#[test]
fn test_set_supportsInterface() {
    let mut state = setup();
    // IERC6909_ID as defined in `interface.cairo` = 0x32cb2c2fe3eafecaa713aaa072ee54795f66abbd45618bd0ff07284d97116ee
    assert!(
        state.supportsInterface(0x32cb2c2fe3eafecaa713aaa072ee54795f66abbd45618bd0ff07284d97116ee)
    );
    assert_eq!(state.supportsInterface(0x32cb), false);
    assert_eq!(
        state.supportsInterface(0x32cb2c2fe3eafecaa713aaa072ee54795f66abbd45618bd0ff07284d97116ef),
        false
    );

    // id == ISRC5_ID || id == IERC6909_ID
    assert!(state.supportsInterface(ISRC5_ID))
}


//
// approve & _approve
//

#[test]
fn test_approve() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert!(state.approve(SPENDER(), TOKEN_ID, VALUE));
    assert_only_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, VALUE);
    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: approve from 0',))]
fn test_approve_from_zero() {
    let mut state = setup();
    state.approve(SPENDER(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: approve to 0',))]
fn test_approve_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(ZERO(), TOKEN_ID, VALUE);
}

#[test]
fn test__approve() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state._approve(OWNER(), SPENDER(), TOKEN_ID, VALUE);
    assert_only_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, VALUE);
    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID,);
    assert_eq!(allowance, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: approve from 0',))]
fn test__approve_from_zero() {
    let mut state = setup();
    state._approve(ZERO(), SPENDER(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: approve to 0',))]
fn test__approve_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state._approve(OWNER(), ZERO(), TOKEN_ID, VALUE);
}

//
// transfer & _transfer
//

#[test]
fn test_transfer() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert!(state.transfer(RECIPIENT(), TOKEN_ID, VALUE));

    assert_only_event_transfer(ZERO(), OWNER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient balance',))]
fn test_transfer_not_enough_balance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    let balance_plus_one = SUPPLY + 1;
    state.transfer(RECIPIENT(), TOKEN_ID, balance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer from 0',))]
fn test_transfer_from_zero() {
    let mut state = setup();
    state.transfer(RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer to 0',))]
fn test_transfer_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transfer(ZERO(), TOKEN_ID, VALUE);
}

#[test]
fn test__transfer() {
    let mut state = setup();
    state._transfer(OWNER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
    assert_only_event_transfer(ZERO(), OWNER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient balance',))]
fn test__transfer_not_enough_balance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    let balance_plus_one = SUPPLY + 1;
    state._transfer(OWNER(), OWNER(), RECIPIENT(), TOKEN_ID, balance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer from 0',))]
fn test__transfer_from_zero() {
    let mut state = setup();
    state._transfer(ZERO(), ZERO(), RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer to 0',))]
fn test__transfer_to_zero() {
    let mut state = setup();
    state._transfer(OWNER(), OWNER(), ZERO(), TOKEN_ID, VALUE);
}

#[test]
fn test_self_transfer() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY);
    assert!(state.transfer(OWNER(), TOKEN_ID, 1));
    assert_only_event_transfer(ZERO(), OWNER(), OWNER(), OWNER(), TOKEN_ID, 1);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY);
}


//
// transfer_from & transferFrom
//

#[test]
fn test_transfer_from() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);
    utils::drop_event(ZERO());

    testing::set_caller_address(SPENDER());
    assert!(state.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE));

    assert_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, 0);
    assert_only_event_transfer(ZERO(), SPENDER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, 0);

    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
}

#[test]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, BoundedInt::max());

    testing::set_caller_address(SPENDER());
    state.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, BoundedInt::max());
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient allowance',))]
fn test_transfer_from_greater_than_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    state.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer to 0',))]
fn test_transfer_from_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(SPENDER());
    state.transfer_from(OWNER(), ZERO(), TOKEN_ID, VALUE);
}

// This does not check `_spend_allowance` since the owner (the zero address) 
// is the sender, see `_spend_allowance` in erc6909.cairo
#[test]
#[should_panic(expected: ('ERC6909: transfer from 0',))]
fn test_transfer_from_from_zero_address() {
    let mut state = setup();
    state.transfer_from(ZERO(), RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient allowance',))]
fn test_transfer_no_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(RECIPIENT());
    state.transfer_from(OWNER(), ZERO(), TOKEN_ID, VALUE);
}

#[test]
fn test_transferFrom() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);
    utils::drop_event(ZERO());

    testing::set_caller_address(SPENDER());
    assert!(state.transferFrom(OWNER(), RECIPIENT(), TOKEN_ID, VALUE));

    assert_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, 0);
    assert_only_event_transfer(ZERO(), SPENDER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, 0);

    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(allowance, 0);
}

#[test]
fn test_transferFrom_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, BoundedInt::max());

    testing::set_caller_address(SPENDER());
    state.transferFrom(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, BoundedInt::max());
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient allowance',))]
fn test_transferFrom_greater_than_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    state.transferFrom(OWNER(), RECIPIENT(), TOKEN_ID, allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer to 0',))]
fn test_transferFrom_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(SPENDER());
    state.transferFrom(OWNER(), ZERO(), TOKEN_ID, VALUE);
}

#[test]
fn test_self_transfer_from() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY);
    assert!(state.transfer_from(OWNER(), OWNER(), TOKEN_ID, 1));
    assert_only_event_transfer(ZERO(), OWNER(), OWNER(), OWNER(), TOKEN_ID, 1);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY);
}


//
// _spend_allowance
//

#[test]
fn test__spend_allowance_not_unlimited() {
    let mut state = setup();

    state._approve(OWNER(), SPENDER(), TOKEN_ID, SUPPLY);
    utils::drop_event(ZERO());

    state._spend_allowance(OWNER(), SPENDER(), TOKEN_ID, VALUE);

    assert_only_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, SUPPLY - VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, SUPPLY - VALUE);
}

#[test]
fn test__spend_allowance_unlimited() {
    let mut state = setup();
    state._approve(OWNER(), SPENDER(), TOKEN_ID, BoundedInt::max());

    let max_minus_one: u256 = BoundedInt::max() - 1;
    state._spend_allowance(OWNER(), SPENDER(), TOKEN_ID, max_minus_one);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, BoundedInt::max());
}

//
// _mint
//

#[test]
fn test__mint() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, VALUE);

    assert_only_event_transfer(ZERO(), ZERO(), ZERO(), OWNER(), TOKEN_ID, VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: mint to 0',))]
fn test__mint_to_zero() {
    let mut state = COMPONENT_STATE();
    state.mint(ZERO(), TOKEN_ID, VALUE);
}

//
// _burn
//

#[test]
fn test__burn() {
    let mut state = setup();
    state.burn(OWNER(), TOKEN_ID, VALUE);

    assert_only_event_transfer(ZERO(), ZERO(), OWNER(), ZERO(), TOKEN_ID, VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: burn from 0',))]
fn test__burn_from_zero() {
    let mut state = setup();
    state.burn(ZERO(), TOKEN_ID, VALUE);
}

//
// is_operator & set_operator
//

#[test]
fn test_transfer_from_caller_is_operator() {
    let mut state = setup();
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY);
    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), 0);
    assert_eq!(state.is_operator(OWNER(), OPERATOR()), false);

    testing::set_caller_address(OWNER());
    state.set_operator(OPERATOR(), true);

    assert_only_event_operator_set(ZERO(), OWNER(), OPERATOR(), true);

    testing::set_caller_address(OPERATOR());
    assert!(state.transfer_from(OWNER(), OPERATOR(), TOKEN_ID, VALUE));
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(state.balance_of(OPERATOR(), TOKEN_ID), VALUE);
    assert!(state.is_operator(OWNER(), OPERATOR()));
}

#[test]
fn test_set_operator() {
    let mut state = setup();
    assert_eq!(state.is_operator(OWNER(), OPERATOR()), false);

    testing::set_caller_address(OWNER());
    state.set_operator(OPERATOR(), true);

    assert_only_event_operator_set(ZERO(), OWNER(), OPERATOR(), true);
    assert!(state.is_operator(OWNER(), OPERATOR()));
}

#[test]
fn test_set_operator_false() {
    let mut state = setup();
    assert_eq!(state.is_operator(OWNER(), OPERATOR()), false);

    testing::set_caller_address(OWNER());
    state.set_operator(OPERATOR(), true);
    assert_only_event_operator_set(ZERO(), OWNER(), OPERATOR(), true);
    assert!(state.is_operator(OWNER(), OPERATOR()));

    testing::set_caller_address(OWNER());
    state.set_operator(OPERATOR(), false);
    assert_only_event_operator_set(ZERO(), OWNER(), OPERATOR(), false);
    assert_eq!(state.is_operator(OWNER(), OPERATOR()), false);
}

#[test]
fn test_operator_does_not_deduct_allowance() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    state.approve(OPERATOR(), TOKEN_ID, 1);
    assert_eq!(state.allowance(OWNER(), OPERATOR(), TOKEN_ID), 1);
    assert_event_approval(ZERO(), OWNER(), OPERATOR(), TOKEN_ID, 1);

    testing::set_caller_address(OWNER());
    state.set_operator(OPERATOR(), true);
    assert!(state.is_operator(OWNER(), OPERATOR()));
    assert_event_operator_set(ZERO(), OWNER(), OPERATOR(), true);

    testing::set_caller_address(OPERATOR());
    assert!(state.transfer_from(OWNER(), OPERATOR(), TOKEN_ID, 1));
    assert_only_event_transfer(ZERO(), OPERATOR(), OWNER(), OPERATOR(), TOKEN_ID, 1);

    assert_eq!(state.allowance(OWNER(), OPERATOR(), TOKEN_ID), 1);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - 1);
    assert_eq!(state.balance_of(OPERATOR(), TOKEN_ID), 1);
}

#[test]
fn test_self_set_operator() {
    let mut state = setup();
    assert_eq!(state.is_operator(OWNER(), OWNER()), false);
    testing::set_caller_address(OWNER());
    state.set_operator(OWNER(), true);
    assert!(state.is_operator(OWNER(), OWNER()));
}
