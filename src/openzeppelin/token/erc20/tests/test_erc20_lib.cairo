use erc20_lib::ERC20Library;

const NAME: felt = 111;
const SYMBOL: felt = 222;
const ACCOUNT1: felt = 1234;
const ACCOUNT2: felt = 5678;

fn setup() -> (u256, u256) {
    let init_supply: u256 = u256_from_felt(2000);
    let value: u256 = u256_from_felt(100);

    ERC20Library::initializer(NAME, SYMBOL, init_supply, ACCOUNT1);
    return (init_supply, value);
}

#[test]
#[available_gas(2000000)]
fn initialize() {
    let init_supply: u256 = u256_from_felt(2000);
    let value: u256 = u256_from_felt(100);
    let decimals: u8 = u8_from_felt(18);

    ERC20Library::initializer(NAME, SYMBOL, init_supply, ACCOUNT1);

    assert(ERC20Library::name() == NAME, 'Name should be NAME');
    assert(ERC20Library::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20Library::decimals() == decimals, 'Decimals should be 18');
    assert(ERC20Library::total_supply() == init_supply, 'Initial supply should be 2000');
    assert(ERC20Library::balance_of(ACCOUNT1) == init_supply, 'Balance should be 2000');
}

#[test]
#[available_gas(2000000)]
fn _approve() {
    let (init_supply, value) = setup();

    ERC20Library::_approve(ACCOUNT1, ACCOUNT2, value);
    assert(ERC20Library::allowance(ACCOUNT1, ACCOUNT2) == value, 'Allowance should be 100');
}

#[test]
#[available_gas(2000000)]
fn _transfer() {
    let (init_supply, value) = setup();

    ERC20Library::_transfer(ACCOUNT1, ACCOUNT2, value);
    assert(ERC20Library::balance_of(ACCOUNT1) == init_supply - value, 'Balance should be 1900');
    assert(ERC20Library::balance_of(ACCOUNT2) == value, 'Balance should be 100');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn _transfer_not_enough_funds() {
    let (init_supply, value) = setup();
    let overflow_amt: u256 = init_supply + u256_from_felt(1);

    ERC20Library::_transfer(ACCOUNT1, ACCOUNT2, overflow_amt);
}

#[test]
#[available_gas(2000000)]
fn _mint() {
    let (init_supply, value) = setup();

    ERC20Library::_mint(ACCOUNT2, value);
    assert(ERC20Library::balance_of(ACCOUNT2) == value, 'Balance should be 100');
}

#[test]
#[available_gas(2000000)]
fn _burn() {
    let (init_supply, value) = setup();

    ERC20Library::_burn(ACCOUNT1, value);
    assert(ERC20Library::balance_of(ACCOUNT1) == init_supply - value, 'Balance should be 1900');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn _burn_not_enough_funds() {
    let (init_supply, value) = setup();
    let overflow_amt: u256 = init_supply + u256_from_felt(1);

    ERC20Library::_burn(ACCOUNT1, overflow_amt);
}
