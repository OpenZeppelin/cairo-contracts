use array::ArrayTrait;
use openzeppelin::tests::mocks::camel20_mock::CamelERC20Mock;
use openzeppelin::tests::mocks::erc20_panic::CamelERC20Panic;
use openzeppelin::tests::mocks::erc20_panic::SnakeERC20Panic;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::mocks::snake20_mock::SnakeERC20Mock;
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::dual20::DualERC20;
use openzeppelin::token::erc20::dual20::DualERC20Trait;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcher;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_contract_address;

//
// Constants
//

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const DECIMALS: u8 = 18_u8;
const SUPPLY: u256 = 2000;
const VALUE: u256 = 300;

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

//
// Setup
//

fn setup_snake() -> (DualERC20, IERC20Dispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME);
    calldata.append_serde(SYMBOL);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(OWNER());
    let target = utils::deploy(SnakeERC20Mock::TEST_CLASS_HASH, calldata);
    (DualERC20 { contract_address: target }, IERC20Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualERC20, IERC20CamelDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME);
    calldata.append_serde(SYMBOL);
    calldata.append_serde(SUPPLY);
    calldata.append_serde(OWNER());
    let target = utils::deploy(CamelERC20Mock::TEST_CLASS_HASH, calldata);
    (DualERC20 { contract_address: target }, IERC20CamelDispatcher { contract_address: target })
}

fn setup_non_erc20() -> DualERC20 {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualERC20 { contract_address: target }
}

fn setup_erc20_panic() -> (DualERC20, DualERC20) {
    let snake_target = utils::deploy(SnakeERC20Panic::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelERC20Panic::TEST_CLASS_HASH, array![]);
    (DualERC20 { contract_address: snake_target }, DualERC20 { contract_address: camel_target })
}

//
// Case agnostic methods
//

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
    set_contract_address(OWNER());
    assert(snake_dispatcher.transfer(RECIPIENT(), VALUE), 'Should return true');
    assert(snake_target.balance_of(RECIPIENT()) == VALUE, 'Should equal VALUE');

    let (camel_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER());
    assert(camel_dispatcher.transfer(RECIPIENT(), VALUE), 'Should return true');
    assert(camel_target.balanceOf(RECIPIENT()) == VALUE, 'Should equal VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_transfer() {
    let dispatcher = setup_non_erc20();
    dispatcher.transfer(RECIPIENT(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transfer_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.transfer(RECIPIENT(), VALUE);
}

#[test]
#[available_gas(2000000)]
fn test_dual_approve() {
    let (snake_dispatcher, snake_target) = setup_snake();
    set_contract_address(OWNER());
    assert(snake_dispatcher.approve(SPENDER(), VALUE), 'Should return true');
    assert(snake_target.allowance(OWNER(), SPENDER()) == VALUE, 'Allowance should equal VALUE');

    let (camel_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER());
    assert(camel_dispatcher.approve(SPENDER(), VALUE), 'Should return true');
    assert(camel_target.allowance(OWNER(), SPENDER()) == VALUE, 'Allowance should equal VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_approve() {
    let dispatcher = setup_non_erc20();
    dispatcher.approve(SPENDER(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_approve_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.approve(SPENDER(), VALUE);
}

//
// snake_case target
//

#[test]
#[available_gas(2000000)]
fn test_dual_total_supply() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.total_supply() == SUPPLY, 'Should return balance');
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
    assert(dispatcher.balance_of(OWNER()) == SUPPLY, 'Should return balance');
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
    set_contract_address(OWNER());
    target.approve(OPERATOR(), VALUE);

    set_contract_address(OPERATOR());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
    assert(target.balance_of(RECIPIENT()) == VALUE, 'Should transfer VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_transfer_from() {
    let dispatcher = setup_non_erc20();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc20_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
}

//
// camelCase target
//

#[test]
#[available_gas(2000000)]
fn test_dual_totalSupply() {
    let (dispatcher, _) = setup_camel();
    assert(dispatcher.total_supply() == SUPPLY, 'Should return supply');
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
    assert(dispatcher.balance_of(OWNER()) == SUPPLY, 'Should return balance');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc20_panic();
    dispatcher.balance_of(OWNER());
}

#[test]
#[available_gas(2000000)]
fn test_dual_transferFrom() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(OWNER());
    target.approve(OPERATOR(), VALUE);

    set_contract_address(OPERATOR());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
    assert(target.balanceOf(RECIPIENT()) == VALUE, 'Should transfer VALUE');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc20_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), VALUE);
}
