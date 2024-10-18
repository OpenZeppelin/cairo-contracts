use crate::common::erc2981::ERC2981Component;
use crate::common::erc2981::interface::{IERC2981ABIDispatcher, IERC2981ABIDispatcherTrait};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{OWNER, OTHER, ZERO, RECIPIENT};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::start_cheat_caller_address;
use starknet::{ContractAddress, contract_address_const};

fn DEFAULT_RECEIVER() -> ContractAddress {
    contract_address_const::<'DEFAULT_RECEIVER'>()
}

// 0.5% (default denominator is 10000)
const DEFAULT_FEE_NUMERATOR: u128 = 50;
// 5% (default denominator is 10000)
const FEE_NUMERATOR: u128 = 500;

fn setup_dispatcher() -> IERC2981ABIDispatcher {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    calldata.append_serde(DEFAULT_RECEIVER());
    calldata.append_serde(DEFAULT_FEE_NUMERATOR);
    let contract_address = utils::declare_and_deploy("ERC2981OwnableMock", calldata);
    IERC2981ABIDispatcher { contract_address }
}

//
// IERC2981Info
//

#[test]
fn test_default_royalty() {
    let dispatcher = setup_dispatcher();

    let (receiver, numerator, denominator) = dispatcher.default_royalty();

    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(numerator, DEFAULT_FEE_NUMERATOR);
    assert_eq!(denominator, ERC2981Component::DEFAULT_FEE_DENOMINATOR);
}

#[test]
fn test_royalty_info_default_royalty() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let sale_price = 1_000_000;

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);
}

//
// IERC2981Admin
//

#[test]
fn test_royalty_info_token_royalty_set() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let sale_price = 1_000_000;

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5_000);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_token_royalty(token_id, RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50_000);
}

#[test]
fn test_set_default_royalty() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let sale_price = 1_000_000;

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5_000);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_default_royalty(RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50_000);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_default_royalty_unauthorized() {
    let dispatcher = setup_dispatcher();

    start_cheat_caller_address(dispatcher.contract_address, OTHER());
    dispatcher.set_default_royalty(RECIPIENT(), FEE_NUMERATOR);
}

#[test]
fn test_set_default_royalty_with_zero_royalty_fraction() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let sale_price = 1_000_000;

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_default_royalty(DEFAULT_RECEIVER(), 0);

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 0);
}

#[test]
#[should_panic(expected: 'ERC2981: invalid receiver')]
fn test_set_default_royalty_with_zero_receiver() {
    let dispatcher = setup_dispatcher();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_default_royalty(ZERO(), FEE_NUMERATOR);
}

#[test]
#[should_panic(expected: 'ERC2981: invalid royalty')]
fn test_set_default_royalty_with_invalid_fee_numerator() {
    let dispatcher = setup_dispatcher();
    let fee_denominator = ERC2981Component::DEFAULT_FEE_DENOMINATOR;

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_default_royalty(DEFAULT_RECEIVER(), fee_denominator + 1);
}

#[test]
fn test_delete_default_royalty() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let sale_price = 1_000_000;

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_default_royalty(RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50_000);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.delete_default_royalty();

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, ZERO());
    assert_eq!(amount, 0);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_delete_default_royalty_unauthorized() {
    let dispatcher = setup_dispatcher();

    start_cheat_caller_address(dispatcher.contract_address, OTHER());
    dispatcher.delete_default_royalty();
}

#[test]
fn test_set_token_royalty() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let another_token_id = 13;
    let sale_price = 1_000_000;

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5_000);

    let (receiver, amount) = dispatcher.royalty_info(another_token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5_000);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_token_royalty(token_id, RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50_000);

    let (receiver, amount) = dispatcher.royalty_info(another_token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5_000);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_token_royalty_unauthorized() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;

    start_cheat_caller_address(dispatcher.contract_address, OTHER());
    dispatcher.set_token_royalty(token_id, RECIPIENT(), FEE_NUMERATOR);
}

#[test]
fn test_set_token_royalty_with_zero_royalty_fraction() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let sale_price = 1_000_000;

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_token_royalty(token_id, RECIPIENT(), 0);

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 0);
}

#[test]
#[should_panic(expected: 'ERC2981: invalid receiver')]
fn test_set_token_royalty_with_zero_receiver() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_token_royalty(token_id, ZERO(), FEE_NUMERATOR);
}

#[test]
#[should_panic(expected: 'ERC2981: invalid royalty')]
fn test_set_token_royalty_with_invalid_fee_numerator() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let fee_denominator = ERC2981Component::DEFAULT_FEE_DENOMINATOR;

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_token_royalty(token_id, RECIPIENT(), fee_denominator + 1);
}

#[test]
fn test_reset_token_royalty() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;
    let sale_price = 1_000_000;

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5_000);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_token_royalty(token_id, RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50_000);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.reset_token_royalty(token_id);

    let (receiver, amount) = dispatcher.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5_000);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_reset_token_royalty_unauthorized() {
    let dispatcher = setup_dispatcher();
    let token_id = 12;

    start_cheat_caller_address(dispatcher.contract_address, OTHER());
    dispatcher.reset_token_royalty(token_id);
}
