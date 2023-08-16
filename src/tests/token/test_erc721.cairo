use ERC721::_owners::InternalContractStateTrait as OwnersTrait;
use ERC721::_token_approvals::InternalContractStateTrait as TokenApprovalsTrait;

use array::ArrayTrait;
use integer::u256;
use integer::u256_from_felt252;
use openzeppelin::account::Account;
use openzeppelin::introspection::src5;
use openzeppelin::introspection;
use openzeppelin::tests::mocks::camel_account_mock::CamelAccountMock;
use openzeppelin::tests::mocks::dual721_receiver_mocks::CamelERC721ReceiverMock;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver;
use openzeppelin::tests::mocks::erc721_receiver::FAILURE;
use openzeppelin::tests::mocks::erc721_receiver::SUCCESS;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{
    ZERO, OWNER, RECIPIENT, SPENDER, OPERATOR, OTHER, NAME, SYMBOL, URI, TOKEN_ID, PUBKEY,
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721::{
    Approval, ApprovalForAll, ERC721CamelOnlyImpl, ERC721Impl, ERC721MetadataCamelOnlyImpl,
    ERC721MetadataImpl, InternalImpl, SRC5CamelImpl, SRC5Impl, Transfer,
};
use openzeppelin::token::erc721::ERC721;
use openzeppelin::token::erc721;
use option::OptionTrait;
use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing;
use traits::Into;
use zeroable::Zeroable;

fn DATA(success: bool) -> Span<felt252> {
    let mut data = array![];
    if success {
        data.append(SUCCESS);
    } else {
        data.append(FAILURE);
    }
    data.span()
}

//
// Setup
//

fn STATE() -> ERC721::ContractState {
    ERC721::contract_state_for_testing()
}

fn setup() -> ERC721::ContractState {
    let mut state = STATE();
    InternalImpl::initializer(ref state, NAME, SYMBOL);
    InternalImpl::_mint(ref state, OWNER(), TOKEN_ID);
    utils::drop_event(ZERO());
    state
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(ERC721Receiver::TEST_CLASS_HASH, array![])
}

fn setup_camel_receiver() -> ContractAddress {
    utils::deploy(CamelERC721ReceiverMock::TEST_CLASS_HASH, array![])
}

fn setup_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(Account::TEST_CLASS_HASH, calldata)
}

fn setup_camel_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(CamelAccountMock::TEST_CLASS_HASH, calldata)
}

//
// Initializers
//

#[test]
#[available_gas(20000000)]
fn test_constructor() {
    let mut state = STATE();
    ERC721::constructor(ref state, NAME, SYMBOL, OWNER(), TOKEN_ID);

    assert(ERC721MetadataImpl::name(@state) == NAME, 'Name should be NAME');
    assert(ERC721MetadataImpl::symbol(@state) == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC721Impl::balance_of(@state, OWNER()) == 1, 'Balance should be one');
    assert(ERC721Impl::owner_of(@state, TOKEN_ID) == OWNER(), 'OWNER should be owner');

    assert(
        SRC5Impl::supports_interface(@state, erc721::interface::IERC721_ID), 'Missing interface ID'
    );
    assert(
        SRC5Impl::supports_interface(@state, erc721::interface::IERC721_METADATA_ID),
        'missing interface ID'
    );
    assert(
        SRC5Impl::supports_interface(@state, introspection::interface::ISRC5_ID),
        'missing interface ID'
    );
}

#[test]
#[available_gas(20000000)]
fn test_initialize() {
    let mut state = STATE();
    InternalImpl::initializer(ref state, NAME, SYMBOL);

    assert(ERC721MetadataImpl::name(@state) == NAME, 'Name should be NAME');
    assert(ERC721MetadataImpl::symbol(@state) == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC721Impl::balance_of(@state, OWNER()) == 0, 'Balance should be zero');

    assert(
        SRC5Impl::supports_interface(@state, erc721::interface::IERC721_ID), 'Missing interface ID'
    );
    assert(
        SRC5Impl::supports_interface(@state, erc721::interface::IERC721_METADATA_ID),
        'missing interface ID'
    );
    assert(
        SRC5Impl::supports_interface(@state, introspection::interface::ISRC5_ID),
        'missing interface ID'
    );
}

//
// Getters
//

#[test]
#[available_gas(20000000)]
fn test_balance_of() {
    let state = setup();
    assert(ERC721Impl::balance_of(@state, OWNER()) == 1, 'Should return balance');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid account', ))]
fn test_balance_of_zero() {
    ERC721Impl::balance_of(@STATE(), ZERO());
}

#[test]
#[available_gas(20000000)]
fn test_owner_of() {
    let state = setup();
    assert(ERC721Impl::owner_of(@state, TOKEN_ID) == OWNER(), 'Should return owner');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_owner_of_non_minted() {
    ERC721Impl::owner_of(@STATE(), u256_from_felt252(7));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_token_uri_non_minted() {
    ERC721MetadataImpl::token_uri(@STATE(), u256_from_felt252(7));
}

#[test]
#[available_gas(20000000)]
fn test_get_approved() {
    let mut state = setup();
    let spender = SPENDER();
    let token_id = TOKEN_ID;

    assert(ERC721Impl::get_approved(@state, token_id) == ZERO(), 'Should return non-approval');
    InternalImpl::_approve(ref state, spender, token_id);
    assert(ERC721Impl::get_approved(@state, token_id) == spender, 'Should return approval');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_get_approved_nonexistent() {
    ERC721Impl::get_approved(@STATE(), u256_from_felt252(7));
}

#[test]
#[available_gas(20000000)]
fn test__exists() {
    let mut state = STATE();
    let zero = ZERO();
    let token_id = TOKEN_ID;

    assert(!InternalImpl::_exists(@state, token_id), 'Token should not exist');
    assert(state._owners.read(token_id) == zero, 'Invalid owner');

    InternalImpl::_mint(ref state, RECIPIENT(), token_id);

    assert(InternalImpl::_exists(@state, token_id), 'Token should exist');
    assert(state._owners.read(token_id) == RECIPIENT(), 'Invalid owner');

    InternalImpl::_burn(ref state, token_id);

    assert(!InternalImpl::_exists(@state, token_id), 'Token should not exist');
    assert(state._owners.read(token_id) == zero, 'Invalid owner');
}

//
// approve & _approve
//

#[test]
#[available_gas(20000000)]
fn test_approve_from_owner() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    ERC721Impl::approve(ref state, SPENDER(), TOKEN_ID);
    assert_event_approval(OWNER(), SPENDER(), TOKEN_ID);

    assert(
        ERC721Impl::get_approved(@state, TOKEN_ID) == SPENDER(), 'Spender not approved correctly'
    );
}

#[test]
#[available_gas(20000000)]
fn test_approve_from_operator() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721Impl::approve(ref state, SPENDER(), TOKEN_ID);
    assert_event_approval(OWNER(), SPENDER(), TOKEN_ID);

    assert(
        ERC721Impl::get_approved(@state, TOKEN_ID) == SPENDER(), 'Spender not approved correctly'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', ))]
fn test_approve_from_unauthorized() {
    let mut state = setup();

    testing::set_caller_address(OTHER());
    ERC721Impl::approve(ref state, SPENDER(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: approval to owner', ))]
fn test_approve_to_owner() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    ERC721Impl::approve(ref state, OWNER(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_approve_nonexistent() {
    let mut state = STATE();
    ERC721Impl::approve(ref state, SPENDER(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
fn test__approve() {
    let mut state = setup();
    InternalImpl::_approve(ref state, SPENDER(), TOKEN_ID);
    assert_event_approval(OWNER(), SPENDER(), TOKEN_ID);

    assert(
        ERC721Impl::get_approved(@state, TOKEN_ID) == SPENDER(), 'Spender not approved correctly'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: approval to owner', ))]
fn test__approve_to_owner() {
    let mut state = setup();
    InternalImpl::_approve(ref state, OWNER(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test__approve_nonexistent() {
    let mut state = STATE();
    InternalImpl::_approve(ref state, SPENDER(), TOKEN_ID);
}

//
// set_approval_for_all & _set_approval_for_all
//

#[test]
#[available_gas(20000000)]
fn test_set_approval_for_all() {
    let mut state = STATE();
    testing::set_caller_address(OWNER());

    assert(!ERC721Impl::is_approved_for_all(@state, OWNER(), OPERATOR()), 'Invalid default value');

    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), true);
    assert_event_approval_for_all(OWNER(), OPERATOR(), true);

    assert(
        ERC721Impl::is_approved_for_all(@state, OWNER(), OPERATOR()),
        'Operator not approved correctly'
    );

    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), false);
    assert_event_approval_for_all(OWNER(), OPERATOR(), false);

    assert(
        !ERC721Impl::is_approved_for_all(@state, OWNER(), OPERATOR()),
        'Approval not revoked correctly'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval', ))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let mut state = STATE();
    testing::set_caller_address(OWNER());
    ERC721Impl::set_approval_for_all(ref state, OWNER(), true);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval', ))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let mut state = STATE();
    testing::set_caller_address(OWNER());
    ERC721Impl::set_approval_for_all(ref state, OWNER(), false);
}

#[test]
#[available_gas(20000000)]
fn test__set_approval_for_all() {
    let mut state = STATE();
    assert(!ERC721Impl::is_approved_for_all(@state, OWNER(), OPERATOR()), 'Invalid default value');

    InternalImpl::_set_approval_for_all(ref state, OWNER(), OPERATOR(), true);
    assert_event_approval_for_all(OWNER(), OPERATOR(), true);

    assert(
        ERC721Impl::is_approved_for_all(@state, OWNER(), OPERATOR()),
        'Operator not approved correctly'
    );

    InternalImpl::_set_approval_for_all(ref state, OWNER(), OPERATOR(), false);
    assert_event_approval_for_all(OWNER(), OPERATOR(), false);

    assert(
        !ERC721Impl::is_approved_for_all(@state, OWNER(), OPERATOR()),
        'Operator not approved correctly'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval', ))]
fn test__set_approval_for_all_owner_equal_operator_true() {
    let mut state = STATE();
    InternalImpl::_set_approval_for_all(ref state, OWNER(), OWNER(), true);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: self approval', ))]
fn test__set_approval_for_all_owner_equal_operator_false() {
    let mut state = STATE();
    InternalImpl::_set_approval_for_all(ref state, OWNER(), OWNER(), false);
}

//
// transfer_from & transferFrom
//

#[test]
#[available_gas(20000000)]
fn test_transfer_from_owner() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();
    // set approval to check reset
    InternalImpl::_approve(ref state, OTHER(), token_id);
    utils::drop_event(ZERO());

    assert_state_before_transfer(owner, recipient, token_id);
    assert(ERC721Impl::get_approved(@state, token_id) == OTHER(), 'Approval not implicitly reset');

    testing::set_caller_address(owner);
    ERC721Impl::transfer_from(ref state, owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_owner() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();
    // set approval to check reset
    InternalImpl::_approve(ref state, OTHER(), token_id);
    utils::drop_event(ZERO());

    assert_state_before_transfer(owner, recipient, token_id);
    assert(ERC721Impl::get_approved(@state, token_id) == OTHER(), 'Approval not implicitly reset');

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::transferFrom(ref state, owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_transfer_from_nonexistent() {
    let mut state = STATE();
    ERC721Impl::transfer_from(ref state, ZERO(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_transferFrom_nonexistent() {
    let mut state = STATE();
    ERC721CamelOnlyImpl::transferFrom(ref state, ZERO(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test_transfer_from_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC721Impl::transfer_from(ref state, OWNER(), ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test_transferFrom_to_zero() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    ERC721CamelOnlyImpl::transferFrom(ref state, OWNER(), ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_to_owner() {
    let mut state = setup();

    assert(ERC721Impl::owner_of(@state, TOKEN_ID) == OWNER(), 'Ownership before');
    assert(ERC721Impl::balance_of(@state, OWNER()) == 1, 'Balance of owner before');

    testing::set_caller_address(OWNER());
    ERC721Impl::transfer_from(ref state, OWNER(), OWNER(), TOKEN_ID);
    assert_event_transfer(OWNER(), OWNER(), TOKEN_ID);

    assert(ERC721Impl::owner_of(@state, TOKEN_ID) == OWNER(), 'Ownership after');
    assert(ERC721Impl::balance_of(@state, OWNER()) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_to_owner() {
    let mut state = setup();

    assert(ERC721Impl::owner_of(@state, TOKEN_ID) == OWNER(), 'Ownership before');
    assert(ERC721Impl::balance_of(@state, OWNER()) == 1, 'Balance of owner before');

    testing::set_caller_address(OWNER());
    ERC721CamelOnlyImpl::transferFrom(ref state, OWNER(), OWNER(), TOKEN_ID);
    assert_event_transfer(OWNER(), OWNER(), TOKEN_ID);

    assert(ERC721Impl::owner_of(@state, TOKEN_ID) == OWNER(), 'Ownership after');
    assert(ERC721Impl::balance_of(@state, OWNER()) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_approved() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(owner, recipient, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::approve(ref state, OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721Impl::transfer_from(ref state, owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_approved() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(owner, recipient, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::approve(ref state, OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721CamelOnlyImpl::transferFrom(ref state, owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_approved_for_all() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(owner, recipient, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721Impl::transfer_from(ref state, owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_approved_for_all() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(owner, recipient, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721CamelOnlyImpl::transferFrom(ref state, owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', ))]
fn test_transfer_from_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    ERC721Impl::transfer_from(ref state, OWNER(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', ))]
fn test_transferFrom_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    ERC721CamelOnlyImpl::transferFrom(ref state, OWNER(), RECIPIENT(), TOKEN_ID);
}

//
// safe_transfer_from & safeTransferFrom
//

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_account() {
    let mut state = setup();
    let account = setup_account();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, account, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, account, token_id, DATA(true));
    assert_event_transfer(owner, account, token_id);

    assert_state_after_transfer(owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_account() {
    let mut state = setup();
    let account = setup_account();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, account, token_id);

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, account, token_id, DATA(true));
    assert_event_transfer(owner, account, token_id);

    assert_state_after_transfer(owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_account_camel() {
    let mut state = setup();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, account, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, account, token_id, DATA(true));
    assert_event_transfer(owner, account, token_id);

    assert_state_after_transfer(owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_account_camel() {
    let mut state = setup();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, account, token_id);

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, account, token_id, DATA(true));
    assert_event_transfer(owner, account, token_id);

    assert_state_after_transfer(owner, account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_receiver() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_receiver() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_receiver_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_receiver_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', ))]
fn test_safe_transfer_from_to_receiver_failure() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', ))]
fn test_safeTransferFrom_to_receiver_failure() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', ))]
fn test_safe_transfer_from_to_receiver_failure_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', ))]
fn test_safeTransferFrom_to_receiver_failure_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_safe_transfer_from_to_non_receiver() {
    let mut state = setup();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, recipient, token_id, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_safeTransferFrom_to_non_receiver() {
    let mut state = setup();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;
    let owner = OWNER();

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, recipient, token_id, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_safe_transfer_from_nonexistent() {
    let mut state = STATE();
    ERC721Impl::safe_transfer_from(ref state, ZERO(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_safeTransferFrom_nonexistent() {
    let mut state = STATE();
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, ZERO(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test_safe_transfer_from_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC721Impl::safe_transfer_from(ref state, OWNER(), ZERO(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test_safeTransferFrom_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, OWNER(), ZERO(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_owner() {
    let mut state = STATE();
    let token_id = TOKEN_ID;
    let owner = setup_receiver();
    InternalImpl::initializer(ref state, NAME, SYMBOL);
    InternalImpl::_mint(ref state, owner, token_id);
    utils::drop_event(ZERO());

    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership before');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner before');

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, owner, token_id, DATA(true));
    assert_event_transfer(owner, owner, token_id);

    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership after');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_owner() {
    let mut state = STATE();
    let token_id = TOKEN_ID;
    let owner = setup_receiver();
    InternalImpl::initializer(ref state, NAME, SYMBOL);
    InternalImpl::_mint(ref state, owner, token_id);
    utils::drop_event(ZERO());

    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership before');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner before');

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, owner, token_id, DATA(true));
    assert_event_transfer(owner, owner, token_id);

    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership after');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_to_owner_camel() {
    let mut state = STATE();
    let token_id = TOKEN_ID;
    let owner = setup_camel_receiver();
    InternalImpl::initializer(ref state, NAME, SYMBOL);
    InternalImpl::_mint(ref state, owner, token_id);
    utils::drop_event(ZERO());

    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership before');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner before');

    testing::set_caller_address(owner);
    ERC721Impl::safe_transfer_from(ref state, owner, owner, token_id, DATA(true));
    assert_event_transfer(owner, owner, token_id);

    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership after');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_to_owner_camel() {
    let mut state = STATE();
    let token_id = TOKEN_ID;
    let owner = setup_camel_receiver();
    InternalImpl::initializer(ref state, NAME, SYMBOL);
    InternalImpl::_mint(ref state, owner, token_id);
    utils::drop_event(ZERO());

    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership before');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner before');

    testing::set_caller_address(owner);
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, owner, token_id, DATA(true));
    assert_event_transfer(owner, owner, token_id);

    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership after');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner after');
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::approve(ref state, OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721Impl::safe_transfer_from(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::approve(ref state, OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::approve(ref state, OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721Impl::safe_transfer_from(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::approve(ref state, OPERATOR(), token_id);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_for_all() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721Impl::safe_transfer_from(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_for_all() {
    let mut state = setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safe_transfer_from_approved_for_all_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721Impl::safe_transfer_from(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
fn test_safeTransferFrom_approved_for_all_camel() {
    let mut state = setup();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_ID;
    let owner = OWNER();

    assert_state_before_transfer(owner, receiver, token_id);

    testing::set_caller_address(owner);
    ERC721Impl::set_approval_for_all(ref state, OPERATOR(), true);
    utils::drop_event(ZERO());

    testing::set_caller_address(OPERATOR());
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, owner, receiver, token_id, DATA(true));
    assert_event_transfer(owner, receiver, token_id);

    assert_state_after_transfer(owner, receiver, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', ))]
fn test_safe_transfer_from_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    ERC721Impl::safe_transfer_from(ref state, OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', ))]
fn test_safeTransferFrom_unauthorized() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    ERC721CamelOnlyImpl::safeTransferFrom(ref state, OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

//
// _transfer
//

#[test]
#[available_gas(20000000)]
fn test__transfer() {
    let mut state = setup();
    let token_id = TOKEN_ID;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(owner, recipient, token_id);

    InternalImpl::_transfer(ref state, owner, recipient, token_id);
    assert_event_transfer(owner, recipient, token_id);

    assert_state_after_transfer(owner, recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test__transfer_nonexistent() {
    let mut state = STATE();
    InternalImpl::_transfer(ref state, ZERO(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test__transfer_to_zero() {
    let mut state = setup();
    InternalImpl::_transfer(ref state, OWNER(), ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: wrong sender', ))]
fn test__transfer_from_invalid_owner() {
    let mut state = setup();
    InternalImpl::_transfer(ref state, RECIPIENT(), OWNER(), TOKEN_ID);
}

//
// _mint
//

#[test]
#[available_gas(20000000)]
fn test__mint() {
    let mut state = STATE();
    let recipient = RECIPIENT();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    InternalImpl::_mint(ref state, recipient, TOKEN_ID);
    assert_event_transfer(ZERO(), recipient, token_id);

    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test__mint_to_zero() {
    let mut state = STATE();
    InternalImpl::_mint(ref state, ZERO(), TOKEN_ID);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: token already minted', ))]
fn test__mint_already_exist() {
    let mut state = setup();
    InternalImpl::_mint(ref state, RECIPIENT(), TOKEN_ID);
}

//
// _safe_mint
//

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_receiver() {
    let mut state = STATE();
    let recipient = setup_receiver();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    InternalImpl::_safe_mint(ref state, recipient, token_id, DATA(true));
    assert_event_transfer(ZERO(), recipient, token_id);

    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_receiver_camel() {
    let mut state = STATE();
    let recipient = setup_camel_receiver();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    InternalImpl::_safe_mint(ref state, recipient, token_id, DATA(true));
    assert_event_transfer(ZERO(), recipient, token_id);

    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_account() {
    let mut state = STATE();
    let account = setup_account();
    let token_id = TOKEN_ID;

    assert_state_before_mint(account);
    InternalImpl::_safe_mint(ref state, account, token_id, DATA(true));
    assert_event_transfer(ZERO(), account, token_id);

    assert_state_after_mint(account, token_id);
}

#[test]
#[available_gas(20000000)]
fn test__safe_mint_to_account_camel() {
    let mut state = STATE();
    let account = setup_camel_account();
    let token_id = TOKEN_ID;

    assert_state_before_mint(account);
    InternalImpl::_safe_mint(ref state, account, token_id, DATA(true));
    assert_event_transfer(ZERO(), account, token_id);

    assert_state_after_mint(account, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test__safe_mint_to_non_receiver() {
    let mut state = STATE();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    InternalImpl::_safe_mint(ref state, recipient, token_id, DATA(true));
    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe mint failed', ))]
fn test__safe_mint_to_receiver_failure() {
    let mut state = STATE();
    let recipient = setup_receiver();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    InternalImpl::_safe_mint(ref state, recipient, token_id, DATA(false));
    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: safe mint failed', ))]
fn test__safe_mint_to_receiver_failure_camel() {
    let mut state = STATE();
    let recipient = setup_camel_receiver();
    let token_id = TOKEN_ID;

    assert_state_before_mint(recipient);
    InternalImpl::_safe_mint(ref state, recipient, token_id, DATA(false));
    assert_state_after_mint(recipient, token_id);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test__safe_mint_to_zero() {
    let mut state = STATE();
    InternalImpl::_safe_mint(ref state, ZERO(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: token already minted', ))]
fn test__safe_mint_already_exist() {
    let mut state = setup();
    InternalImpl::_safe_mint(ref state, RECIPIENT(), TOKEN_ID, DATA(true));
}

//
// _burn
//

#[test]
#[available_gas(20000000)]
fn test__burn() {
    let mut state = setup();

    InternalImpl::_approve(ref state, OTHER(), TOKEN_ID);
    utils::drop_event(ZERO());

    assert(ERC721Impl::owner_of(@state, TOKEN_ID) == OWNER(), 'Ownership before');
    assert(ERC721Impl::balance_of(@state, OWNER()) == 1, 'Balance of owner before');
    assert(ERC721Impl::get_approved(@state, TOKEN_ID) == OTHER(), 'Approval before');

    InternalImpl::_burn(ref state, TOKEN_ID);
    assert_event_transfer(OWNER(), ZERO(), TOKEN_ID);

    assert(state._owners.read(TOKEN_ID) == ZERO(), 'Ownership after');
    assert(ERC721Impl::balance_of(@state, OWNER()) == 0, 'Balance of owner after');
    assert(state._token_approvals.read(TOKEN_ID) == ZERO(), 'Approval after');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test__burn_nonexistent() {
    let mut state = STATE();
    InternalImpl::_burn(ref state, TOKEN_ID);
}

//
// _set_token_uri
//

#[test]
#[available_gas(20000000)]
fn test__set_token_uri() {
    let mut state = setup();

    assert(ERC721MetadataImpl::token_uri(@state, TOKEN_ID) == 0, 'URI should be 0');
    InternalImpl::_set_token_uri(ref state, TOKEN_ID, URI);
    assert(ERC721MetadataImpl::token_uri(@state, TOKEN_ID) == URI, 'URI should be set');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test__set_token_uri_nonexistent() {
    let mut state = STATE();
    InternalImpl::_set_token_uri(ref state, TOKEN_ID, URI);
}

//
// Helpers
//

fn assert_state_before_transfer(
    owner: ContractAddress, recipient: ContractAddress, token_id: u256
) {
    let state = STATE();
    assert(ERC721Impl::owner_of(@state, token_id) == owner, 'Ownership before');
    assert(ERC721Impl::balance_of(@state, owner) == 1, 'Balance of owner before');
    assert(ERC721Impl::balance_of(@state, recipient) == 0, 'Balance of recipient before');
}

fn assert_state_after_transfer(owner: ContractAddress, recipient: ContractAddress, token_id: u256) {
    let state = STATE();
    assert(ERC721Impl::owner_of(@state, token_id) == recipient, 'Ownership after');
    assert(ERC721Impl::balance_of(@state, owner) == 0, 'Balance of owner after');
    assert(ERC721Impl::balance_of(@state, recipient) == 1, 'Balance of recipient after');
    assert(ERC721Impl::get_approved(@state, token_id) == ZERO(), 'Approval not implicitly reset');
}

fn assert_state_before_mint(recipient: ContractAddress) {
    let state = STATE();
    assert(ERC721Impl::balance_of(@state, recipient) == 0, 'Balance of recipient before');
}

fn assert_state_after_mint(recipient: ContractAddress, token_id: u256) {
    let state = STATE();
    assert(ERC721Impl::owner_of(@state, token_id) == recipient, 'Ownership after');
    assert(ERC721Impl::balance_of(@state, recipient) == 1, 'Balance of recipient after');
    assert(ERC721Impl::get_approved(@state, token_id) == ZERO(), 'Approval implicitly set');
}

fn assert_event_approval_for_all(
    owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ApprovalForAll>(ZERO()).unwrap();
    assert(event.owner == owner, 'Invalid `owner`');
    assert(event.operator == operator, 'Invalid `operator`');
    assert(event.approved == approved, 'Invalid `approved`');
    utils::assert_no_events_left(ZERO());
}

fn assert_event_approval(owner: ContractAddress, approved: ContractAddress, token_id: u256) {
    let event = utils::pop_log::<Approval>(ZERO()).unwrap();
    assert(event.owner == owner, 'Invalid `owner`');
    assert(event.approved == approved, 'Invalid `approved`');
    assert(event.token_id == token_id, 'Invalid `token_id`');
    utils::assert_no_events_left(ZERO());
}

fn assert_event_transfer(from: ContractAddress, to: ContractAddress, token_id: u256) {
    let event = utils::pop_log::<Transfer>(ZERO()).unwrap();
    assert(event.from == from, 'Invalid `from`');
    assert(event.to == to, 'Invalid `to`');
    assert(event.token_id == token_id, 'Invalid `token_id`');
    utils::assert_no_events_left(ZERO());
}
