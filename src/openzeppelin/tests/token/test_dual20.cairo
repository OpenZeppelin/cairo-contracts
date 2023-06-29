use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_contract_address;
use traits::Into;

use openzeppelin::tests::mocks::camel20_mock::CamelERC20Mock;
use openzeppelin::tests::mocks::erc20_panic::SnakeERC20Panic;
use openzeppelin::tests::mocks::erc20_panic::CamelERC20Panic;
use openzeppelin::tests::mocks::non721_mock::NonERC721;
use openzeppelin::tests::mocks::snake20_mock::SnakeERC20Mock;
use openzeppelin::token::erc20::dual20::DualERC20;
use openzeppelin::token::erc20::dual20::DualERC20Trait;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcher;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin::tests::utils;

///
/// Constants
///

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const DECIMALS: u8 = 18_u8;

fn SUPPLY() -> u256 {
    2000_u256
}
fn VALUE() -> u256 {
    300_u256
}
fn OWNER() -> ContractAddress {
    contract_address_const::<10>()
}
fn SPENDER() -> ContractAddress {
    contract_address_const::<20>()
}
fn RECIPIENT() -> ContractAddress {
    contract_address_const::<30>()
}
fn OPERATOR() -> ContractAddress {
    contract_address_const::<40>()
}

///
/// Setup
///

fn setup_snake() -> (DualERC20, IERC20Dispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append(NAME);
    calldata.append(SYMBOL);
    calldata.append(SUPPLY().low.into());
    calldata.append(SUPPLY().high.into());
    calldata.append(OWNER().into());
    let target = utils::deploy(SnakeERC20Mock::TEST_CLASS_HASH, calldata);
    (DualERC20 { contract_address: target }, IERC20Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualERC20, IERC20CamelDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append(NAME);
    calldata.append(SYMBOL);
    calldata.append(SUPPLY().low.into());
    calldata.append(SUPPLY().high.into());
    calldata.append(OWNER().into());
    let target = utils::deploy(CamelERC20Mock::TEST_CLASS_HASH, calldata);
    (DualERC20 { contract_address: target }, IERC20CamelDispatcher { contract_address: target })
}

fn setup_non_erc20() -> DualERC20 {
    let calldata = ArrayTrait::new();
    let target = utils::deploy(NonERC721::TEST_CLASS_HASH, calldata);
    DualERC20 { contract_address: target }
}

fn setup_erc20_panic() -> (DualERC20, DualERC20) {
    let snake_target = utils::deploy(SnakeERC20Panic::TEST_CLASS_HASH, ArrayTrait::new());
    let camel_target = utils::deploy(CamelERC20Panic::TEST_CLASS_HASH, ArrayTrait::new());
    (DualERC20 { contract_address: snake_target }, DualERC20 { contract_address: camel_target })
}

///
/// Case agnostic methods
///

#[test]
#[available_gas(2000000)]
fn test_dual_name() {
    let (snake_dual_dispatcher, _) = setup_snake();
    let (camel_dual_dispatcher, _) = setup_camel();
    assert(snake_dual_dispatcher.name() == NAME, 'Should return name');
    assert(camel_dual_dispatcher.name() == NAME, 'Should return name');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_name() {
    let dual_dispatcher = setup_non_erc20();
    dual_dispatcher.name();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_name_exists_and_panics() {
    let (dual_dispatcher, _) = setup_erc20_panic();
    dual_dispatcher.name();
}

#[test]
#[available_gas(2000000)]
fn test_dual_symbol() {
    let (snake_dual_dispatcher, _) = setup_snake();
    let (camel_dual_dispatcher, _) = setup_camel();
    assert(snake_dual_dispatcher.symbol() == SYMBOL, 'Should return symbol');
    assert(camel_dual_dispatcher.symbol() == SYMBOL, 'Should return symbol');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_symbol() {
    let dual_dispatcher = setup_non_erc20();
    dual_dispatcher.symbol();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_symbol_exists_and_panics() {
    let (dual_dispatcher, _) = setup_erc20_panic();
    dual_dispatcher.symbol();
}

#[test]
#[available_gas(2000000)]
fn test_dual_decimals() {
    let (snake_dual_dispatcher, _) = setup_snake();
    let (camel_dual_dispatcher, _) = setup_camel();
    assert(snake_dual_dispatcher.decimals() == DECIMALS, 'Should return symbol');
    assert(camel_dual_dispatcher.decimals() == DECIMALS, 'Should return symbol');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_decimals() {
    let dual_dispatcher = setup_non_erc20();
    dual_dispatcher.decimals();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_decimals_exists_and_panics() {
    let (dual_dispatcher, _) = setup_erc20_panic();
    dual_dispatcher.decimals();
}

#[test]
#[available_gas(2000000)]
fn test_dual_transfer() {
    let (snake_dual_dispatcher, snake_target) = setup_snake();
    set_contract_address(OWNER());
    assert(snake_dual_dispatcher.transfer(RECIPIENT(), VALUE()), 'Should return true');
    assert(snake_target.balance_of(RECIPIENT()) == VALUE(), 'Should equal VALUE');

    let (camel_dual_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER());
    assert(camel_dual_dispatcher.transfer(RECIPIENT(), VALUE()), 'Should return true');
    assert(camel_target.balanceOf(RECIPIENT()) == VALUE(), 'Should equal VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_transfer() {
    let dual_dispatcher = setup_non_erc20();
    dual_dispatcher.transfer(RECIPIENT(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transfer_exists_and_panics() {
    let (dual_dispatcher, _) = setup_erc20_panic();
    dual_dispatcher.transfer(RECIPIENT(), VALUE());
}

#[test]
#[available_gas(2000000)]
fn test_dual_approve() {
    let (snake_dual_dispatcher, snake_target) = setup_snake();
    set_contract_address(OWNER());
    assert(snake_dual_dispatcher.approve(SPENDER(), VALUE()), 'Should return true');
    assert(snake_target.allowance(OWNER(), SPENDER()) == VALUE(), 'Allowance should equal VALUE');

    let (camel_dual_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER());
    assert(camel_dual_dispatcher.approve(SPENDER(), VALUE()), 'Should return true');
    assert(camel_target.allowance(OWNER(), SPENDER()) == VALUE(), 'Allowance should equal VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_approve() {
    let dual_dispatcher = setup_non_erc20();
    dual_dispatcher.approve(SPENDER(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_approve_exists_and_panics() {
    let (dual_dispatcher, _) = setup_erc20_panic();
    dual_dispatcher.approve(SPENDER(), VALUE());
}

///
/// snake_case target
///

#[test]
#[available_gas(2000000)]
fn test_dual_total_supply() {
    let (dual_dispatcher, _) = setup_snake();
    assert(dual_dispatcher.total_supply() == SUPPLY(), 'Should return balance');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_total_supply() {
    let dual_dispatcher = setup_non_erc20();
    dual_dispatcher.total_supply();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_total_supply_exists_and_panics() {
    let (dual_dispatcher, _) = setup_erc20_panic();
    dual_dispatcher.total_supply();
}

#[test]
#[available_gas(2000000)]
fn test_dual_balance_of() {
    let (dual_dispatcher, _) = setup_snake();
    assert(dual_dispatcher.balance_of(OWNER()) == SUPPLY(), 'Should return balance');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_balance_of() {
    let dual_dispatcher = setup_non_erc20();
    dual_dispatcher.balance_of(OWNER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_balance_of_exists_and_panics() {
    let (dual_dispatcher, _) = setup_erc20_panic();
    dual_dispatcher.balance_of(OWNER());
}

#[test]
#[available_gas(2000000)]
fn test_dual_transfer_from() {
    let (dual_dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    target.approve(OPERATOR(), VALUE());

    set_contract_address(OPERATOR());
    dual_dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
    assert(target.balance_of(RECIPIENT()) == VALUE(), 'Should transfer VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_transfer_from() {
    let dual_dispatcher = setup_non_erc20();
    dual_dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transfer_from_exists_and_panics() {
    let (dual_dispatcher, _) = setup_erc20_panic();
    dual_dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
}

///
/// camelCase target
///

#[test]
#[available_gas(2000000)]
fn test_dual_totalSupply() {
    let (dual_dispatcher, _) = setup_camel();
    assert(dual_dispatcher.total_supply() == SUPPLY(), 'Should return supply');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_totalSupply_exists_and_panics() {
    let (_, dual_dispatcher) = setup_erc20_panic();
    dual_dispatcher.total_supply();
}

#[test]
#[available_gas(2000000)]
fn test_dual_balanceOf() {
    let (dual_dispatcher, _) = setup_camel();
    assert(dual_dispatcher.balance_of(OWNER()) == SUPPLY(), 'Should return balance');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dual_dispatcher) = setup_erc20_panic();
    dual_dispatcher.balance_of(OWNER());
}

#[ignore] // Potential bug mentioned here: https://github.com/starkware-libs/cairo/issues/3432
#[test]
#[available_gas(2000000)]
fn test_dual_transferFrom() {
    let (dual_dispatcher, target) = setup_camel();
    set_contract_address(OWNER());
    target.approve(OPERATOR(), VALUE());

    set_contract_address(OPERATOR());
    dual_dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
    assert(target.balanceOf(RECIPIENT()) == VALUE(), 'Should transfer VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transferFrom_exists_and_panics() {
    let (_, dual_dispatcher) = setup_erc20_panic();
    dual_dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
}
