use core::pedersen::pedersen;
use openzeppelin::presets::universal_deployer::UniversalDeployer::ContractDeployed;
use openzeppelin::presets::universal_deployer::UniversalDeployer;
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL, SUPPLY, SALT, CALLER, RECIPIENT};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::universal_deployer::interface::{
    IUniversalDeployerDispatcher, IUniversalDeployerDispatcherTrait
};
use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::testing;


// 2**251 - 256
const L2_ADDRESS_UPPER_BOUND: felt252 =
    0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00;
const CONTRACT_ADDRESS_PREFIX: felt252 = 'STARKNET_CONTRACT_ADDRESS';

fn ERC20_CLASS_HASH() -> ClassHash {
    DualCaseERC20Mock::TEST_CLASS_HASH.try_into().unwrap()
}

fn ERC20_CALLDATA() -> Span<felt252> {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(SUPPLY);
    calldata.append_serde(RECIPIENT());
    calldata.span()
}

fn deploy_udc() -> IUniversalDeployerDispatcher {
    let calldata = array![];
    let address = utils::deploy(UniversalDeployer::TEST_CLASS_HASH, calldata);

    IUniversalDeployerDispatcher { contract_address: address }
}

#[test]
fn test_deploy_not_unique() {
    let udc = deploy_udc();
    let unique = false;
    testing::set_contract_address(CALLER());

    // Check address
    let expected_addr = calculate_contract_address_from_hash(
        SALT, ERC20_CLASS_HASH(), ERC20_CALLDATA(), Zeroable::zero()
    );
    let deployed_addr = udc.deploy_contract(ERC20_CLASS_HASH(), SALT, unique, ERC20_CALLDATA());
    assert_eq!(expected_addr, deployed_addr);

    // Check event
    assert_only_event_contract_deployed(
        udc.contract_address,
        deployed_addr,
        CALLER(),
        unique,
        ERC20_CLASS_HASH(),
        ERC20_CALLDATA(),
        SALT
    );

    // Check deployment
    let erc20 = IERC20Dispatcher { contract_address: deployed_addr };
    let total_supply = erc20.total_supply();
    assert_eq!(total_supply, SUPPLY);
}

#[test]
fn test_deploy_unique() {
    let udc = deploy_udc();
    let unique = true;
    testing::set_contract_address(CALLER());

    // Check address
    let hashed_salt = pedersen(CALLER().into(), SALT);
    let expected_addr = calculate_contract_address_from_hash(
        hashed_salt, ERC20_CLASS_HASH(), ERC20_CALLDATA(), udc.contract_address
    );
    let deployed_addr = udc.deploy_contract(ERC20_CLASS_HASH(), SALT, unique, ERC20_CALLDATA());
    assert_eq!(expected_addr, deployed_addr);

    // Check event
    assert_only_event_contract_deployed(
        udc.contract_address,
        deployed_addr,
        CALLER(),
        unique,
        ERC20_CLASS_HASH(),
        ERC20_CALLDATA(),
        SALT
    );

    // Check deployment
    let erc20 = IERC20Dispatcher { contract_address: deployed_addr };
    let total_supply = erc20.total_supply();
    assert_eq!(total_supply, SUPPLY);
}

//
// Helpers
//

/// See https://github.com/starkware-libs/cairo-lang/blob/v0.13.0/src/starkware/cairo/common/hash_state.py
fn compute_hash_on_elements(mut data: Span<felt252>) -> felt252 {
    let data_len: usize = data.len();
    let mut hash = 0;
    loop {
        match data.pop_front() {
            Option::Some(elem) => { hash = pedersen(hash, *elem); },
            Option::None => {
                hash = pedersen(hash, data_len.into());
                break;
            },
        };
    };
    hash
}

/// See https://github.com/starkware-libs/cairo-lang/blob/v0.13.0/src/starkware/starknet/core/os/contract_address/contract_address.py
fn calculate_contract_address_from_hash(
    salt: felt252,
    class_hash: ClassHash,
    constructor_calldata: Span<felt252>,
    deployer_address: ContractAddress
) -> ContractAddress {
    let constructor_calldata_hash = compute_hash_on_elements(constructor_calldata);

    let mut data = array![];
    data.append_serde(CONTRACT_ADDRESS_PREFIX);
    data.append_serde(deployer_address);
    data.append_serde(salt);
    data.append_serde(class_hash);
    data.append_serde(constructor_calldata_hash);
    let raw_address = compute_hash_on_elements(data.span());

    // Felt modulo is discouraged, hence the conversion to u256
    let u256_addr: u256 = raw_address.into() % L2_ADDRESS_UPPER_BOUND.into();
    let felt_addr = u256_addr.try_into().unwrap();
    starknet::contract_address_try_from_felt252(felt_addr).unwrap()
}

fn assert_only_event_contract_deployed(
    contract: ContractAddress,
    address: ContractAddress,
    deployer: ContractAddress,
    unique: bool,
    class_hash: ClassHash,
    calldata: Span<felt252>,
    salt: felt252
) {
    let event = utils::pop_log::<UniversalDeployer::Event>(contract).unwrap();
    let expected = UniversalDeployer::Event::ContractDeployed(
        ContractDeployed { address, deployer, unique, class_hash, calldata, salt }
    );
    assert!(event == expected);
    utils::assert_no_events_left(contract);
}
