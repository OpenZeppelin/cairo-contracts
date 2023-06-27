use openzeppelin::introspection::erc165;
use openzeppelin::token::erc721;
use openzeppelin::token::erc721::ERC721;
use openzeppelin::account::Account;

use openzeppelin::tests::utils;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver;
use openzeppelin::tests::mocks::erc721_receiver::ERC721NonReceiver;
use openzeppelin::tests::mocks::erc721_receiver::SUCCESS;
use openzeppelin::tests::mocks::erc721_receiver::FAILURE;

use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing::set_caller_address;
use integer::u256;
use integer::u256_from_felt252;
use array::ArrayTrait;
use traits::Into;
use zeroable::Zeroable;

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const URI: felt252 = 333;

fn TOKEN_ID() -> u256 {
    7.into()
}

fn ZERO() -> ContractAddress {
    Zeroable::zero()
}
fn OWNER() -> ContractAddress {
    contract_address_const::<10>()
}
fn RECIPIENT() -> ContractAddress {
    contract_address_const::<20>()
}
fn SPENDER() -> ContractAddress {
    contract_address_const::<30>()
}
fn OPERATOR() -> ContractAddress {
    contract_address_const::<40>()
}
fn OTHER() -> ContractAddress {
    contract_address_const::<50>()
}

fn DATA(success: bool) -> Span<felt252> {
    let mut data = ArrayTrait::new();
    if success {
        data.append(SUCCESS);
    } else {
        data.append(FAILURE);
    }
    data.span()
}

///
/// Setup
///

fn setup() {
    ERC721::initializer(NAME, SYMBOL);
    ERC721::_mint(OWNER(), TOKEN_ID());
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(ERC721Receiver::TEST_CLASS_HASH, ArrayTrait::new())
}

fn setup_account() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let public_key: felt252 = 1234678;
    calldata.append(public_key);
    utils::deploy(Account::TEST_CLASS_HASH, calldata)
}

///
/// Initializers
///

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    ERC721::constructor(NAME, SYMBOL);

    assert(ERC721::name() == NAME, 'Name should be NAME');
    assert(ERC721::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance should be zero');

    assert(ERC721::supports_interface(erc721::interface::IERC721_ID), 'Missing interface ID');
    assert(
        ERC721::supports_interface(erc721::interface::IERC721_METADATA_ID), 'missing interface ID'
    );
    assert(ERC721::supports_interface(erc165::IERC165_ID), 'missing interface ID');
    assert(!ERC721::supports_interface(erc165::INVALID_ID), 'invalid interface ID');
}

#[test]
#[available_gas(2000000)]
fn test_initialize() {
    ERC721::initializer(NAME, SYMBOL);

    assert(ERC721::name() == NAME, 'Name should be NAME');
    assert(ERC721::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance should be zero');

    assert(ERC721::supports_interface(erc721::interface::IERC721_ID), 'Missing interface ID');
    assert(
        ERC721::supports_interface(erc721::interface::IERC721_METADATA_ID), 'missing interface ID'
    );
    assert(ERC721::supports_interface(erc165::IERC165_ID), 'missing interface ID');
    assert(!ERC721::supports_interface(erc165::INVALID_ID), 'invalid interface ID');
}

///
/// Getters
///

#[test]
#[available_gas(2000000)]
fn test_balance_of() {
    setup();
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Should return balance');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid account', ))]
fn test_balance_of_zero() {
    ERC721::balance_of(ZERO());
}

#[test]
#[available_gas(2000000)]
fn test_owner_of() {
    setup();
    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Should return owner');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_owner_of_non_minted() {
    ERC721::owner_of(u256_from_felt252(7));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_token_uri_non_minted() {
    ERC721::token_uri(u256_from_felt252(7));
}

#[test]
#[available_gas(2000000)]
fn test_get_approved() {
    setup();
    let spender = SPENDER();
    let token_id = TOKEN_ID();

    assert(ERC721::get_approved(token_id) == ZERO(), 'Should return non-approval');
    ERC721::_approve(spender, token_id);
    assert(ERC721::get_approved(token_id) == spender, 'Should return approval');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_get_approved_nonexistent() {
    ERC721::get_approved(u256_from_felt252(7));
}

#[test]
#[available_gas(2000000)]
fn test__exists() {
    let zero = ZERO();
    let token_id = TOKEN_ID();
    assert(!ERC721::_exists(token_id), 'Token should not exist');
    assert(ERC721::_owners::read(token_id) == zero, 'Invalid owner');

    ERC721::_mint(RECIPIENT(), token_id);

    assert(ERC721::_exists(token_id), 'Token should exist');
    assert(ERC721::_owners::read(token_id) == RECIPIENT(), 'Invalid owner');

    ERC721::_burn(token_id);

    assert(!ERC721::_exists(token_id), 'Token should not exist');
    assert(ERC721::_owners::read(token_id) == zero, 'Invalid owner');
}

///
/// approve & _approve
///

#[test]
#[available_gas(2000000)]
fn test_approve_from_owner() {
    setup();

    set_caller_address(OWNER());
    ERC721::approve(SPENDER(), TOKEN_ID());
    assert(ERC721::get_approved(TOKEN_ID()) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
fn test_approve_from_operator() {
    setup();

    set_caller_address(OWNER());
    ERC721::set_approval_for_all(OPERATOR(), true);

    set_caller_address(OPERATOR());
    ERC721::approve(SPENDER(), TOKEN_ID());
    assert(ERC721::get_approved(TOKEN_ID()) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', ))]
fn test_approve_from_unauthorized() {
    setup();

    set_caller_address(OTHER());
    ERC721::approve(SPENDER(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: approval to owner', ))]
fn test_approve_to_owner() {
    setup();

    set_caller_address(OWNER());
    ERC721::approve(OWNER(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_approve_nonexistent() {
    ERC721::approve(SPENDER(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
fn test__approve() {
    setup();

    ERC721::_approve(SPENDER(), TOKEN_ID());
    assert(ERC721::get_approved(TOKEN_ID()) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: approval to owner', ))]
fn test__approve_to_owner() {
    setup();

    ERC721::_approve(OWNER(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test__approve_nonexistent() {
    ERC721::_approve(SPENDER(), TOKEN_ID());
}

///
/// set_approval_for_all & _set_approval_for_all
///

#[test]
#[available_gas(2000000)]
fn test_set_approval_for_all() {
    set_caller_address(OWNER());
    assert(!ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    ERC721::set_approval_for_all(OPERATOR(), true);
    assert(ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');

    ERC721::set_approval_for_all(OPERATOR(), false);
    assert(!ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Approval not revoked correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: self approval', ))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    set_caller_address(OWNER());
    ERC721::set_approval_for_all(OWNER(), true);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: self approval', ))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    set_caller_address(OWNER());
    ERC721::set_approval_for_all(OWNER(), false);
}

#[test]
#[available_gas(2000000)]
fn test__set_approval_for_all() {
    assert(!ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    ERC721::_set_approval_for_all(OWNER(), OPERATOR(), true);
    assert(ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');

    ERC721::_set_approval_for_all(OWNER(), OPERATOR(), false);
    assert(!ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: self approval', ))]
fn test__set_approval_for_all_owner_equal_operator_true() {
    ERC721::_set_approval_for_all(OWNER(), OWNER(), true);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: self approval', ))]
fn test__set_approval_for_all_owner_equal_operator_false() {
    ERC721::_set_approval_for_all(OWNER(), OWNER(), false);
}

///
/// transfer_from
///

#[test]
#[available_gas(2000000)]
fn test_transfer_from_owner() {
    setup();
    let token_id = TOKEN_ID();
    let owner = OWNER();
    let recipient = RECIPIENT();
    // set approval to check reset
    ERC721::_approve(OTHER(), token_id);

    assert_state_before_transfer(token_id, owner, recipient);
    assert(ERC721::get_approved(token_id) == OTHER(), 'Approval not implicitly reset');

    set_caller_address(owner);
    ERC721::transfer_from(owner, recipient, token_id);

    assert_state_after_transfer(token_id, owner, recipient);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_transfer_from_nonexistent() {
    ERC721::transfer_from(ZERO(), RECIPIENT(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test_transfer_from_to_zero() {
    setup();

    set_caller_address(OWNER());
    ERC721::transfer_from(OWNER(), ZERO(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_to_owner() {
    setup();

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership before');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner before');

    set_caller_address(OWNER());
    ERC721::transfer_from(OWNER(), OWNER(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership after');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner after');
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_approved() {
    setup();
    let token_id = TOKEN_ID();
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(token_id, owner, recipient);

    set_caller_address(owner);
    ERC721::approve(OPERATOR(), token_id);

    set_caller_address(OPERATOR());
    ERC721::transfer_from(owner, recipient, token_id);

    assert_state_after_transfer(token_id, owner, recipient);
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_approved_for_all() {
    setup();
    let token_id = TOKEN_ID();
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(token_id, owner, recipient);

    set_caller_address(owner);
    ERC721::set_approval_for_all(OPERATOR(), true);

    set_caller_address(OPERATOR());
    ERC721::transfer_from(owner, recipient, token_id);

    assert_state_after_transfer(token_id, owner, recipient);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', ))]
fn test_transfer_from_unauthorized() {
    setup();

    set_caller_address(OTHER());
    ERC721::transfer_from(OWNER(), RECIPIENT(), TOKEN_ID());
}

//
// safe_transfer_from
//

#[test]
#[available_gas(2000000)]
fn test_safe_transfer_from_to_account() {
    setup();
    let account = setup_account();
    let token_id = TOKEN_ID();
    let owner = OWNER();

    assert_state_before_transfer(token_id, owner, account);

    set_caller_address(owner);
    ERC721::safe_transfer_from(owner, account, token_id, DATA(true));

    assert_state_after_transfer(token_id, owner, account);
}

#[test]
#[available_gas(2000000)]
fn test_safe_transfer_from_to_receiver() {
    setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID();
    let owner = OWNER();

    assert_state_before_transfer(token_id, owner, receiver);

    set_caller_address(owner);
    ERC721::safe_transfer_from(owner, receiver, token_id, DATA(true));

    assert_state_after_transfer(token_id, owner, receiver);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: safe transfer failed', ))]
fn test_safe_transfer_from_to_receiver_failure() {
    setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID();
    let owner = OWNER();

    set_caller_address(owner);
    ERC721::safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_safe_transfer_from_to_non_receiver() {
    setup();
    let recipient = utils::deploy(ERC721NonReceiver::TEST_CLASS_HASH, ArrayTrait::new());
    let token_id = TOKEN_ID();
    let owner = OWNER();

    set_caller_address(owner);
    ERC721::safe_transfer_from(owner, recipient, token_id, DATA(true));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test_safe_transfer_from_nonexistent() {
    ERC721::safe_transfer_from(ZERO(), RECIPIENT(), TOKEN_ID(), DATA(true));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test_safe_transfer_from_to_zero() {
    setup();

    set_caller_address(OWNER());
    ERC721::safe_transfer_from(OWNER(), ZERO(), TOKEN_ID(), DATA(true));
}

#[test]
#[available_gas(2000000)]
fn test_safe_transfer_from_to_owner() {
    let token_id = TOKEN_ID();
    let owner = setup_receiver();
    ERC721::initializer(NAME, SYMBOL);
    ERC721::_mint(owner, token_id);

    assert(ERC721::owner_of(token_id) == owner, 'Ownership before');
    assert(ERC721::balance_of(owner) == 1.into(), 'Balance of owner before');

    set_caller_address(owner);
    ERC721::safe_transfer_from(owner, owner, token_id, DATA(true));

    assert(ERC721::owner_of(token_id) == owner, 'Ownership after');
    assert(ERC721::balance_of(owner) == 1.into(), 'Balance of owner after');
}

#[test]
#[available_gas(2000000)]
fn test_safe_transfer_from_approved() {
    setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID();
    let owner = OWNER();

    assert_state_before_transfer(token_id, owner, receiver);

    set_caller_address(owner);
    ERC721::approve(OPERATOR(), token_id);

    set_caller_address(OPERATOR());
    ERC721::safe_transfer_from(owner, receiver, token_id, DATA(true));

    assert_state_after_transfer(token_id, owner, receiver);
}

#[test]
#[available_gas(2000000)]
fn test_safe_transfer_from_approved_for_all() {
    setup();
    let receiver = setup_receiver();
    let token_id = TOKEN_ID();
    let owner = OWNER();

    assert_state_before_transfer(token_id, owner, receiver);

    set_caller_address(owner);
    ERC721::set_approval_for_all(OPERATOR(), true);

    set_caller_address(OPERATOR());
    ERC721::safe_transfer_from(owner, receiver, token_id, DATA(true));

    assert_state_after_transfer(token_id, owner, receiver);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: unauthorized caller', ))]
fn test_safe_transfer_from_unauthorized() {
    setup();
    set_caller_address(OTHER());
    ERC721::safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID(), DATA(true));
}

//
// __transfer
//

#[test]
#[available_gas(2000000)]
fn test__transfer() {
    setup();
    let token_id = TOKEN_ID();
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(token_id, owner, recipient);
    ERC721::_transfer(owner, recipient, token_id);
    assert_state_after_transfer(token_id, owner, recipient);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test__transfer_nonexistent() {
    ERC721::_transfer(ZERO(), RECIPIENT(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test__transfer_to_zero() {
    setup();

    ERC721::_transfer(OWNER(), ZERO(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: wrong sender', ))]
fn test__transfer_from_invalid_owner() {
    setup();

    ERC721::_transfer(RECIPIENT(), OWNER(), TOKEN_ID());
}

///
/// Mint
///

#[test]
#[available_gas(2000000)]
fn test__mint() {
    let recipient = RECIPIENT();
    let token_id = TOKEN_ID();
    assert_state_before_mint(recipient);
    ERC721::_mint(RECIPIENT(), TOKEN_ID());
    assert_state_after_mint(token_id, recipient);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test__mint_to_zero() {
    ERC721::_mint(ZERO(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: token already minted', ))]
fn test__mint_already_exist() {
    setup();

    ERC721::_mint(RECIPIENT(), TOKEN_ID());
}

///
/// _safe_mint
///

#[test]
#[available_gas(2000000)]
fn test__safe_mint_to_receiver() {
    let recipient = setup_receiver();
    let token_id = TOKEN_ID();

    assert_state_before_mint(recipient);
    ERC721::_safe_mint(recipient, token_id, DATA(true));
    assert_state_after_mint(token_id, recipient);
}

#[test]
#[available_gas(2000000)]
fn test__safe_mint_to_account() {
    let account = setup_account();
    let token_id = TOKEN_ID();

    assert_state_before_mint(account);
    ERC721::_safe_mint(account, token_id, DATA(true));
    assert_state_after_mint(token_id, account);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test__safe_mint_to_non_receiver() {
    let recipient = utils::deploy(ERC721NonReceiver::TEST_CLASS_HASH, ArrayTrait::new());
    let token_id = TOKEN_ID();

    assert_state_before_mint(recipient);
    ERC721::_safe_mint(recipient, token_id, DATA(true));
    assert_state_after_mint(token_id, recipient);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: safe mint failed', ))]
fn test__safe_mint_to_receiver_failure() {
    let recipient = setup_receiver();
    let token_id = TOKEN_ID();

    assert_state_before_mint(recipient);
    ERC721::_safe_mint(recipient, token_id, DATA(false));
    assert_state_after_mint(token_id, recipient);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid receiver', ))]
fn test__safe_mint_to_zero() {
    ERC721::_safe_mint(ZERO(), TOKEN_ID(), DATA(true));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: token already minted', ))]
fn test__safe_mint_already_exist() {
    setup();
    ERC721::_safe_mint(RECIPIENT(), TOKEN_ID(), DATA(true));
}

///
/// Burn
///

#[test]
#[available_gas(2000000)]
fn test__burn() {
    setup();

    ERC721::_approve(OTHER(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership before');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner before');
    assert(ERC721::get_approved(TOKEN_ID()) == OTHER(), 'Approval before');

    ERC721::_burn(TOKEN_ID());

    assert(ERC721::_owners::read(TOKEN_ID()) == ZERO(), 'Ownership after');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance of owner after');
    assert(ERC721::_token_approvals::read(TOKEN_ID()) == ZERO(), 'Approval after');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test__burn_nonexistent() {
    ERC721::_burn(TOKEN_ID());
}

///
/// _set_token_uri
///

#[test]
#[available_gas(2000000)]
fn test__set_token_uri() {
    setup();

    assert(ERC721::token_uri(TOKEN_ID()) == 0, 'URI should be 0');
    ERC721::_set_token_uri(TOKEN_ID(), URI);
    assert(ERC721::token_uri(TOKEN_ID()) == URI, 'URI should be set');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: invalid token ID', ))]
fn test__set_token_uri_nonexistent() {
    ERC721::_set_token_uri(TOKEN_ID(), URI);
}

//
// Helpers
//

fn assert_state_before_transfer(
    token_id: u256, owner: ContractAddress, recipient: ContractAddress
) {
    assert(ERC721::owner_of(token_id) == owner, 'Ownership before');
    assert(ERC721::balance_of(owner) == 1.into(), 'Balance of owner before');
    assert(ERC721::balance_of(recipient) == 0.into(), 'Balance of recipient before');
}

fn assert_state_after_transfer(token_id: u256, owner: ContractAddress, recipient: ContractAddress) {
    assert(ERC721::owner_of(token_id) == recipient, 'Ownership after');
    assert(ERC721::balance_of(owner) == 0.into(), 'Balance of owner after');
    assert(ERC721::balance_of(recipient) == 1.into(), 'Balance of recipient after');
    assert(ERC721::get_approved(token_id) == ZERO(), 'Approval not implicitly reset');
}

fn assert_state_before_mint(recipient: ContractAddress) {
    assert(ERC721::balance_of(recipient) == 0.into(), 'Balance of recipient before');
}

fn assert_state_after_mint(token_id: u256, recipient: ContractAddress) {
    assert(ERC721::owner_of(token_id) == recipient, 'Ownership after');
    assert(ERC721::balance_of(recipient) == 1.into(), 'Balance of recipient after');
    assert(ERC721::get_approved(token_id) == ZERO(), 'Approval implicitly set');
}
