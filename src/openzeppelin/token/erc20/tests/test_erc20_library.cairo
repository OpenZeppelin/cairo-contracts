/// Tests only the internal functions of the erc20 library because
/// `get_caller_address` is not yet functional with accounts.
///
/// Events are not yet recognized in starknet tests.
/// Some of these tests will panic with 'Unknown selector for system call!'
/// Comment out events in erc20/erc20.cairo to omit panicking.

use erc20::ERC20Library;
use starknet::contract_address_const;
use integer::u256_from_felt;

const NAME: felt = 111;
const SYMBOL: felt = 222;

fn setup() -> (ContractAddress, u256) {
    let account: ContractAddress = contract_address_const::<1>();
    let initial_supply: u256 = u256_from_felt(2000);

    ERC20Library::mock_initializer(NAME, SYMBOL);
    ERC20Library::_total_supply::write(initial_supply);
    ERC20Library::_balances::write(account, initial_supply);
    (account, initial_supply)
}

#[test]
#[available_gas(2000000)]
fn initialize() {
    let decimals: u8 = 18_u8;

    ERC20Library::mock_initializer(NAME, SYMBOL);

    assert(ERC20Library::name() == NAME, 'Name should be NAME');
    assert(ERC20Library::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20Library::decimals() == decimals, 'Decimals should be 18');
}

#[test]
#[available_gas(2000000)]
fn test__approve() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::_approve(owner, spender, amount);
    assert(ERC20Library::allowance(owner, spender) == amount, 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__approve_from_zero() {
    let owner: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<1>();
    let amount: u256 = u256_from_felt(100);
    ERC20Library::_approve(owner, spender, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__approve_to_zero() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt(100);
    ERC20Library::_approve(owner, spender, amount);
}

#[test]
#[available_gas(2000000)]
fn test__transfer() {
    let (account, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);
    ERC20Library::_transfer(account, recipient, amount);

    assert(ERC20Library::balance_of(recipient) == amount, 'Balance should eq amount');
    assert(ERC20Library::balance_of(account) == supply - amount, 'Should eq supply - amount');
    assert(ERC20Library::total_supply() == supply, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__transfer_not_enough_balance() {
    let (account, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let amount: u256 = supply + u256_from_felt(1);
    ERC20Library::_transfer(account, recipient, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__transfer_from_zero() {
    let owner: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<1>();
    let amount: u256 = u256_from_felt(100);
    ERC20Library::_transfer(owner, spender, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__transfer_to_zero() {
    let (account, supply) = setup();

    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt(100);
    ERC20Library::_transfer(account, spender, amount);
}

#[test]
#[available_gas(2000000)]
fn test__spend_allowance_not_unlimited() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::_approve(owner, spender, supply);
    ERC20Library::_spend_allowance(owner, spender, amount);
    assert(ERC20Library::allowance(owner, spender) == supply - amount, 'Should eq supply - amount');
}

#[test]
#[available_gas(2000000)]
fn test__spend_allowance_unlimited() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();

    let max_u256: u256 = u256_from_felt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) * u256_from_felt(256) + u256_from_felt(255);
    let max_minus_one: u256 = max_u256 - u256_from_felt(1);

    ERC20Library::_approve(owner, spender, max_u256);
    ERC20Library::_spend_allowance(owner, spender, max_minus_one);

    assert(ERC20Library::allowance(owner, spender) == max_u256, 'Allowance should not change');
}

#[test]
#[available_gas(2000000)]
fn test__mint() {
    let minter: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::_mint(minter, amount);

    assert(ERC20Library::total_supply() == amount, 'Should eq total supply');
    // assert(ERC20Library::balance_of(minter) == amount, 'Should eq amount');
    // Causes 'Error: Failed setting up runner'
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__mint_to_zero() {
    let minter: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::_mint(minter, amount);
}

#[test]
#[available_gas(2000000)]
fn test__burn() {
    let (owner, supply) = setup();

    let amount: u256 = u256_from_felt(100);
    ERC20Library::_burn(owner, amount);

    assert(ERC20Library::total_supply() == supply - amount, 'Should eq supply - amount');
    assert(ERC20Library::balance_of(owner) == supply - amount, 'Should eq supply - amount');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__burn_from_zero() {
    setup();
    let zero_address: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::_burn(zero_address, amount);
}
