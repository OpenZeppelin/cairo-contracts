use erc20::ERC20Library;
use starknet::contract_address_const;
use starknet_testing::set_caller_address;
use integer::u256_from_felt;

const NAME: felt = 111;
const SYMBOL: felt = 222;

fn setup() -> (ContractAddress, u256) {
    let initial_supply: u256 = u256_from_felt(2000);
    let account: ContractAddress = contract_address_const::<1>();
    // Set caller
    starknet_testing::set_caller_address(account);

    ERC20Library::initializer(NAME, SYMBOL, initial_supply, account);
    (account, initial_supply)
}

fn set_caller_as_zero() {
    starknet_testing::set_caller_address(contract_address_const::<0>());
}

#[test]
#[available_gas(2000000)]
fn initialize() {
    let initial_supply: u256 = u256_from_felt(2000);
    let account: ContractAddress = contract_address_const::<1>();
    let decimals: u8 = 18_u8;

    ERC20Library::initializer(NAME, SYMBOL, initial_supply, account);

    let owner_balance: u256 = ERC20Library::balance_of(account);
    assert(owner_balance == initial_supply, 'Should eq inital_supply');

    assert(ERC20Library::total_supply() == initial_supply, 'Should eq inital_supply');
    assert(ERC20Library::name() == NAME, 'Name should be NAME');
    assert(ERC20Library::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20Library::decimals() == decimals, 'Decimals should be 18');
}

#[test]
#[available_gas(2000000)]
fn test_approve() {
    let (owner, supply) = setup();
    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    let result: bool = ERC20Library::approve(spender, amount);
    assert(result, '');
    assert(ERC20Library::allowance(owner, spender) == amount, 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_approve_from_zero() {
    let (owner, supply) = setup();
    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    set_caller_as_zero();

    ERC20Library::approve(spender, amount);
    assert(ERC20Library::allowance(owner, spender) == amount, 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_approve_to_zero() {
    let (owner, supply) = setup();
    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::approve(spender, amount);
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
fn test_transfer() {
    let (sender, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);
    let success: bool = ERC20Library::transfer(recipient, amount);

    assert(success, '');
    assert(ERC20Library::balance_of(recipient) == amount, 'Balance should eq amount');
    assert(ERC20Library::balance_of(sender) == supply - amount, 'Should eq supply - amount');
    assert(ERC20Library::total_supply() == supply, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test__transfer() {
    let (sender, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);
    ERC20Library::_transfer(sender, recipient, amount);

    assert(ERC20Library::balance_of(recipient) == amount, 'Balance should eq amount');
    assert(ERC20Library::balance_of(sender) == supply - amount, 'Should eq supply - amount');
    assert(ERC20Library::total_supply() == supply, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__transfer_not_enough_balance() {
    let (sender, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let amount: u256 = supply + u256_from_felt(1);
    ERC20Library::_transfer(sender, recipient, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__transfer_from_zero() {
    let sender: ContractAddress = contract_address_const::<0>();
    let recipient: ContractAddress = contract_address_const::<1>();
    let amount: u256 = u256_from_felt(100);
    ERC20Library::_transfer(sender, recipient, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test__transfer_to_zero() {
    let (sender, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt(100);
    ERC20Library::_transfer(sender, recipient, amount);
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from() {
    let (owner, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::approve(spender, amount);

    starknet_testing::set_caller_address(spender);

    let success: bool = ERC20Library::transfer_from(owner, recipient, amount);
    assert(success, 'Should return success');

    // Will dangle without setting as a var
    let spender_allowance: u256 = ERC20Library::allowance(owner, spender);

    assert(ERC20Library::balance_of(recipient) == amount, 'Should eq amount');
    assert(ERC20Library::balance_of(owner) == supply - amount, 'Should eq suppy - amount');
    assert(spender_allowance == u256_from_felt(0), 'Should eq 0');
    assert(ERC20Library::total_supply() == supply, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    let (owner, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt(100);
    let max_u256: u256 = u256_from_felt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) * u256_from_felt(256) + u256_from_felt(255);

    ERC20Library::approve(spender, max_u256);

    starknet_testing::set_caller_address(spender);

    ERC20Library::transfer_from(owner, recipient, amount);

    let spender_allowance: u256 = ERC20Library::allowance(owner, spender);
    assert(spender_allowance == max_u256, 'Should remain max_uint256');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_transfer_from_greater_than_allowance() {
    let (owner, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt(100);
    let amount_plus_one: u256 = amount + u256_from_felt(1);

    ERC20Library::approve(spender, amount);

    starknet_testing::set_caller_address(spender);

    ERC20Library::transfer_from(owner, recipient, amount_plus_one);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_transfer_from_to_zero_address() {
    let (owner, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::approve(spender, amount);

    starknet_testing::set_caller_address(spender);

    ERC20Library::transfer_from(owner, recipient, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_transfer_from_from_zero_address() {
    let (owner, supply) = setup();

    let zero_address: ContractAddress = contract_address_const::<0>();
    let recipient: ContractAddress = contract_address_const::<2>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt(100);

    starknet_testing::set_caller_address(zero_address);

    ERC20Library::transfer_from(owner, recipient, amount);
}

#[test]
#[available_gas(2000000)]
fn test_increase_allowance() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::approve(spender, amount);
    ERC20Library::increase_allowance(spender, amount);

    let spender_allowance: u256 = ERC20Library::allowance(owner, spender);
    assert(spender_allowance == amount + amount, '');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_increase_allowance_to_zero_address() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::increase_allowance(spender, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_increase_allowance_from_zero_address() {
    let (owner, supply) = setup();

    let zero_address: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    starknet_testing::set_caller_address(zero_address);

    ERC20Library::increase_allowance(spender, amount);
}

#[test]
#[available_gas(2000000)]
fn test_decrease_allowance() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::approve(spender, amount);
    ERC20Library::decrease_allowance(spender, amount);

    let spender_allowance: u256 = ERC20Library::allowance(owner, spender);
    assert(spender_allowance == amount - amount, '');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_decrease_allowance_to_zero_address() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt(100);

    ERC20Library::decrease_allowance(spender, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_decrease_allowance_from_zero_address() {
    let (owner, supply) = setup();

    let zero_address: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt(100);

    starknet_testing::set_caller_address(zero_address);

    ERC20Library::decrease_allowance(spender, amount);
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

    let minter_balance: u256 = ERC20Library::balance_of(minter);
    assert(minter_balance == amount, 'Should eq amount');

    assert(ERC20Library::total_supply() == amount, 'Should eq total supply');
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
