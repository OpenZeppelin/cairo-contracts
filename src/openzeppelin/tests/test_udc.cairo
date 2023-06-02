use array::ArrayTrait;
use core::result::ResultTrait;
use core::traits::Into;
use debug::PrintTrait;
use option::OptionTrait;
use starknet::class_hash::ClassHash;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;
use starknet::contract_address_const;
use traits::TryInto;
use zeroable::Zeroable;
use super::utils;

use openzeppelin::utils::universal_deployer::UniversalDeployer;
use openzeppelin::utils::universal_deployer::IUniversalDeployerDispatcher;
use openzeppelin::utils::universal_deployer::IUniversalDeployerDispatcherTrait;

use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::IERC20Dispatcher;
use openzeppelin::token::erc20::IERC20DispatcherTrait;

const RAW_SALT: felt252 = 123456789;

fn ACCOUNT() -> ContractAddress {
    contract_address_const::<10>()
}

fn deploy_udc() -> IUniversalDeployerDispatcher {
    let calldata = ArrayTrait::<felt252>::new();
    let (address, _) = starknet::deploy_syscall(
        UniversalDeployer::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    IUniversalDeployerDispatcher { contract_address: address }
}

#[test]
#[available_gas(2000000)]
fn test_deploy_not_unique() {
    let udc = deploy_udc();

    // udc args
    let erc20_class_hash = ERC20::TEST_CLASS_HASH.try_into().unwrap();
    let unique = false;

    // calldata (erc20 args)
    let name = 0;
    let symbol = 0;
    let initial_supply = 1000_u256;
    let recipient = contract_address_const::<0x123>();
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(name);
    calldata.append(symbol);
    calldata.append(initial_supply.low.into());
    calldata.append(initial_supply.high.into());
    calldata.append(recipient.into());

    let expected_addr = utils::calculate_contract_address_from_hash(
        RAW_SALT, erc20_class_hash, calldata.span(), Zeroable::zero()
    );

    let deployed_addr = udc.deploy_contract(erc20_class_hash, RAW_SALT, unique, calldata.span());
/// assert(deployed_addr == expected_addr, 'Deployed address != expected');
}

#[test]
#[available_gas(2000000)]
fn test_deploy_unique() {
    let udc = deploy_udc();

    // udc args
    let erc20_class_hash = ERC20::TEST_CLASS_HASH.try_into().unwrap();
    let unique = true;

    // calldata (erc20 args)
    let name = 0;
    let symbol = 0;
    let initial_supply = 1000_u256;
    let recipient = contract_address_const::<0x123>();
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(name);
    calldata.append(symbol);
    calldata.append(initial_supply.low.into());
    calldata.append(initial_supply.high.into());
    calldata.append(recipient.into());

    let hashed_salt = pedersen(ACCOUNT().into(), RAW_SALT);
    let expected_addr = utils::calculate_contract_address_from_hash(
        hashed_salt, erc20_class_hash, calldata.span(), udc.contract_address
    );

    let deployed_addr = udc.deploy_contract(erc20_class_hash, hashed_salt, unique, calldata.span());
/// assert(deployed_addr == expected_addr, 'Deployed address != expected');
}

