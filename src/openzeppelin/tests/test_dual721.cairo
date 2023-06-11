use traits::Into;
use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;
use openzeppelin::token::erc721::ERC721;
use openzeppelin::token::erc721::interface::IERC721;
use openzeppelin::token::erc721::interface::IERC721Camel;
use openzeppelin::token::erc721::interface::IERC721Dispatcher;
use openzeppelin::token::erc721::interface::IERC721CamelDispatcher;
use openzeppelin::token::erc721::interface::IERC721DispatcherTrait;
use openzeppelin::token::erc721::interface::IERC721CamelDispatcherTrait;
use openzeppelin::token::erc721::dual721::DualERC721Trait;
use openzeppelin::token::erc721::dual721::DualERC721;
use openzeppelin::tests::mocks::snake721_mock::SnakeERC721Mock;
use openzeppelin::tests::mocks::camel721_mock::CamelERC721Mock;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver;
use openzeppelin::tests::mocks::erc721_receiver::SUCCESS;
use openzeppelin::tests::mocks::erc721_receiver::FAILURE;
use openzeppelin::tests::utils;

///
/// constants
///

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const URI: felt252 = 333;

fn TOKEN_ID() -> u256 {
    7.into()
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
/// setup
///

fn setup_snake() -> (DualERC721, IERC721Dispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append(NAME);
    calldata.append(SYMBOL);
    calldata.append(TOKEN_ID().low.into());
    calldata.append(TOKEN_ID().high.into());
    set_caller_address(OWNER());
    let target = utils::deploy(SnakeERC721Mock::TEST_CLASS_HASH, calldata);
    (
        DualERC721 { target: target },
        IERC721Dispatcher{ contract_address: target }
    )
}

fn setup_camel() -> (DualERC721, IERC721CamelDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append(NAME);
    calldata.append(SYMBOL);
    calldata.append(TOKEN_ID().low.into());
    calldata.append(TOKEN_ID().high.into());
    set_caller_address(OWNER());
    let target = utils::deploy(CamelERC721Mock::TEST_CLASS_HASH, calldata);
    (
        DualERC721 { target: target },
        IERC721CamelDispatcher{ contract_address: target }
    )
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(ERC721Receiver::TEST_CLASS_HASH, ArrayTrait::new())
}

///
/// case agnostic methods
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
fn test_dual_symbol() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert(snake_dispatcher.symbol() == SYMBOL, 'Should return symbol');
    assert(camel_dispatcher.symbol() == SYMBOL, 'Should return symbol');
}

#[test]
#[available_gas(2000000)]
fn test_dual_approve() {
    // to do: fix
    let (snake_dispatcher, snake_target) = setup_snake();
    set_caller_address(OWNER());
    snake_target.approve(SPENDER(), TOKEN_ID());
    assert(snake_target.get_approved(TOKEN_ID()) == SPENDER(), 'Spender not approved correctly');

    let (camel_dispatcher, camel_target) = setup_camel();
    camel_dispatcher.approve(SPENDER(), TOKEN_ID());
    assert(camel_target.getApproved(TOKEN_ID()) == SPENDER(), 'Spender not approved correctly');
}

///
/// snake_case target
///

#[test]
#[available_gas(2000000)]
fn test_dual_balance_of() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.balance_of(OWNER()) == 1, 'Should return balance');
}

#[test]
#[available_gas(2000000)]
fn test_dual_owner_of() {
    let (dispatcher, target) = setup_snake();
    assert(dispatcher.owner_of(TOKEN_ID()) == OWNER(), 'Should return owner');
}

#[test]
#[available_gas(2000000)]
fn test_dual_transfer_from() {
    let (dispatcher, target) = setup_snake();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID());
    assert(target.owner_of(TOKEN_ID()) == RECIPIENT(), 'Should transfer token');
}

#[test]
#[available_gas(2000000)]
fn test_dual_safe_transfer_from() {
    // to do: fix
    let (dispatcher, target) = setup_snake();
    let receiver = setup_receiver();
    dispatcher.safe_transfer_from(OWNER(), receiver, TOKEN_ID(), DATA(true));
    assert(dispatcher.owner_of(TOKEN_ID()) == OWNER(), 'Should transfer token');
}

#[test]
#[available_gas(2000000)]
fn test_dual_get_approved() {
    // to do: depends on approve()
    // let (dispatcher, target) = setup_snake();
}

#[test]
#[available_gas(2000000)]
fn test_dual_set_approval_for_all() {
    // to do: fix
    let (dispatcher, target) = setup_snake();
    dispatcher.set_approval_for_all(OPERATOR(), true);
    assert(target.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
fn test_dual_is_approved_for_all() {
    // to do: depends on set_approval_for_all()
    let (dispatcher, target) = setup_snake();
    target.set_approval_for_all(OPERATOR(), true);
    assert(dispatcher.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
fn test_dual_token_uri() {
    // let (dispatcher, target) = setup_snake();
}

///
/// camelCase target
///

#[test]
#[available_gas(2000000)]
fn test_dual_balanceOf() {
    let (dispatcher, _) = setup_camel();
    assert(dispatcher.balance_of(OWNER()) == 1, 'Should return balance');
}

#[test]
#[available_gas(2000000)]
fn test_dual_ownerOf() {
    let (dispatcher, target) = setup_camel();
    assert(dispatcher.owner_of(TOKEN_ID()) == OWNER(), 'Should return owner');
}

#[test]
#[available_gas(2000000)]
fn test_dual_transferFrom() {
    let (dispatcher, target) = setup_camel();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID());
    assert(target.ownerOf(TOKEN_ID()) == RECIPIENT(), 'Should transfer token');
}

#[test]
#[available_gas(2000000)]
fn test_dual_safeTransferFrom() {
    // to do: fix
    let (dispatcher, target) = setup_camel();
    let receiver = setup_receiver();
    dispatcher.safe_transfer_from(OWNER(), receiver, TOKEN_ID(), DATA(true));
    assert(target.ownerOf(TOKEN_ID()) == OWNER(), 'Should transfer token');
}

#[test]
#[available_gas(2000000)]
fn test_dual_getApproved() {
    // to do: depends on approve()
    // let (dispatcher, target) = setup_camel();
}

#[test]
#[available_gas(2000000)]
fn test_dual_setApprovalForAll() {
    let (dispatcher, target) = setup_camel();

    dispatcher.set_approval_for_all(OPERATOR(), true);
    assert(target.isApprovedForAll(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
fn test_dual_isApprovedForAll() {
    // to do: depends on setApprovalForAll()
    let (dispatcher, target) = setup_camel();
    target.setApprovalForAll(OPERATOR(), true);
    assert(dispatcher.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
fn test_dualTokenUri() {
}

///
/// failures
///

#[test]
#[available_gas(2000000)]
fn test_dual_non_existent() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_exists_but_reverts() {
}
