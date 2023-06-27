use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;
use traits::Into;

use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::interface::IERC20;
use openzeppelin::token::erc20::interface::IERC20Camel;
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcher;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use openzeppelin::token::erc20::dual20::DualERC20Trait;
use openzeppelin::token::erc20::dual20::DualERC20;
use openzeppelin::tests::mocks::snake20_mock::SnakeERC20Mock;
use openzeppelin::tests::mocks::camel20_mock::CamelERC20Mock;
use openzeppelin::tests::mocks::erc20_panic::SnakeERC20Panic;
use openzeppelin::tests::mocks::erc20_panic::CamelERC20Panic;
use openzeppelin::tests::mocks::non721_mock::NonERC721;
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
    (DualERC20 { target: target }, IERC20Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualERC20, IERC20CamelDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append(NAME);
    calldata.append(SYMBOL);
    calldata.append(SUPPLY().low.into());
    calldata.append(SUPPLY().high.into());
    calldata.append(OWNER().into());
    let target = utils::deploy(CamelERC20Mock::TEST_CLASS_HASH, calldata);
    (DualERC20 { target: target }, IERC20CamelDispatcher { contract_address: target })
}

fn setup_non_erc20() -> DualERC20 {
    let calldata = ArrayTrait::new();
    let target = utils::deploy(NonERC721::TEST_CLASS_HASH, calldata);
    DualERC20 { target: target }
}

fn setup_erc20_panic() -> (DualERC20, DualERC20) {
    let snake_target = utils::deploy(SnakeERC20Panic::TEST_CLASS_HASH, ArrayTrait::new());
    let camel_target = utils::deploy(CamelERC20Panic::TEST_CLASS_HASH, ArrayTrait::new());
    (DualERC20 { target: snake_target }, DualERC20 { target: camel_target })
}

///
/// Case agnostic methods
///

#[test]
#[available_gas(2000000)]
fn test_dual_name() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert(snake_dispatcher.name() == NAME, 'Should return name');
    assert(camel_dispatcher.name() == NAME, 'Should return name');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_name() {
    let dispatcher = setup_non_erc20();
    dispatcher.name();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_name_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.name();
}

#[test]
#[available_gas(2000000)]
fn test_dual_symbol() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert(snake_dispatcher.symbol() == SYMBOL, 'Should return symbol');
    assert(camel_dispatcher.symbol() == SYMBOL, 'Should return symbol');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_symbol() {
    let dispatcher = setup_non_erc20();
    dispatcher.symbol();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_symbol_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.symbol();
}

#[test]
#[available_gas(2000000)]
fn test_dual_decimals() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert(snake_dispatcher.decimals() == DECIMALS, 'Should return symbol');
    assert(camel_dispatcher.decimals() == DECIMALS, 'Should return symbol');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_decimals() {
    let dispatcher = setup_non_erc20();
    dispatcher.decimals();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_decimals_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.decimals();
}

#[test]
#[available_gas(2000000)]
fn test_dual_transfer() {
    let (snake_dispatcher, snake_target) = setup_snake();
    set_contract_address(OWNER()); // Bug with test-runner
    assert(snake_target.transfer(RECIPIENT(), VALUE()), 'Should return true');
    assert(snake_target.balance_of(RECIPIENT()) == VALUE(), 'Tokens not sent correctly');

    let (camel_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER()); // Bug with test-runner
    assert(camel_dispatcher.transfer(RECIPIENT(), VALUE()), 'Should return true');
    assert(camel_target.balanceOf(RECIPIENT()) == VALUE(), 'Tokens not sent correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_transfer() {
    let dispatcher = setup_non_erc20();
    dispatcher.transfer(RECIPIENT(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transfer_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.transfer(RECIPIENT(), VALUE());
}

#[test]
#[available_gas(2000000)]
fn test_dual_approved() {
    let (snake_dispatcher, snake_target) = setup_snake();
    set_contract_address(OWNER()); // Bug with test-runner
    assert(snake_target.approve(SPENDER(), VALUE()), 'Should return true');
    assert(snake_target.allowance(OWNER(), SPENDER()) == VALUE(), 'Spender not approved correctly');

    let (camel_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER()); // Bug with test-runner
    assert(camel_dispatcher.approve(SPENDER(), VALUE()), 'Should return true');
    assert(camel_target.allowance(OWNER(), SPENDER()) == VALUE(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_approve() {
    let dispatcher = setup_non_erc20();
    dispatcher.approve(SPENDER(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_approve_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.approve(SPENDER(), VALUE());
}

///
/// snake_case target
///

#[test]
#[available_gas(2000000)]
fn test_dual_total_supply() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.total_supply() == SUPPLY(), 'Should return balance');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_total_supply() {
    let dispatcher = setup_non_erc20();
    dispatcher.total_supply();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_total_supply_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.total_supply();
}

#[test]
#[available_gas(2000000)]
fn test_dual_balance_of() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.balance_of(OWNER()) == SUPPLY(), 'Should return balance');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_balance_of() {
    let dispatcher = setup_non_erc20();
    dispatcher.balance_of(OWNER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_balance_of_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.balance_of(OWNER());
}

#[test]
#[available_gas(2000000)]
fn test_dual_transfer_from() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER()); // Bug with test-runner
    target.approve(OPERATOR(), VALUE());

    set_contract_address(OPERATOR());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
    assert(target.balance_of(RECIPIENT()) == VALUE(), 'Should transfer VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_transfer_from() {
    let dispatcher = setup_non_erc20();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
}

///
/// camelCase target
///

#[test]
#[available_gas(2000000)]
fn test_dual_totalSupply() {
    let (dispatcher, _) = setup_camel();
    assert(dispatcher.total_supply() == SUPPLY(), 'Should return supply');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_totalSupply_exists_and_panics() {
    let (_, dispatcher) = setup_erc20_panic();
    dispatcher.total_supply();
}

#[test]
#[available_gas(2000000)]
fn test_dual_balanceOf() {
    let (dispatcher, _) = setup_camel();
    assert(dispatcher.balance_of(OWNER()) == SUPPLY(), 'Should return balance');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc20_panic();
    dispatcher.balance_of(OWNER());
}

#[ignore] // Bug with test-runner
#[test]
#[available_gas(2000000)]
fn test_dual_transferFrom() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(OWNER()); // Bug with test-runner
    target.approve(OPERATOR(), VALUE());

    set_contract_address(OPERATOR());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
    assert(target.balanceOf(RECIPIENT()) == VALUE(), 'Should transfer VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc20_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE());
}
