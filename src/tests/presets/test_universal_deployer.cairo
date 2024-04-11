use openzeppelin::presets::universal_deployer::UniversalDeployer::ContractDeployed;
use openzeppelin::presets::universal_deployer::UniversalDeployer;
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL, SUPPLY, SALT, CALLER, RECIPIENT};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::deployments::{DeployerInfo, calculate_contract_address_from_udc};
use openzeppelin::utils::interfaces::{
    IUniversalDeployerDispatcher, IUniversalDeployerDispatcherTrait
};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::testing;


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
fn test_deploy_from_zero() {
    let udc = deploy_udc();
    let from_zero = true;
    testing::set_contract_address(CALLER());

    // Check address
    let expected_addr = calculate_contract_address_from_udc(
        SALT, ERC20_CLASS_HASH(), ERC20_CALLDATA(), Option::None
    );
    let deployed_addr = udc.deploy_contract(ERC20_CLASS_HASH(), SALT, from_zero, ERC20_CALLDATA());
    assert_eq!(expected_addr, deployed_addr);

    // Check event
    assert_only_event_contract_deployed(
        udc.contract_address,
        deployed_addr,
        CALLER(),
        from_zero,
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
fn test_deploy_not_from_zero() {
    let udc = deploy_udc();
    let from_zero = false;
    testing::set_contract_address(CALLER());

    // Check address
    let expected_addr = calculate_contract_address_from_udc(
        SALT,
        ERC20_CLASS_HASH(),
        ERC20_CALLDATA(),
        Option::Some(DeployerInfo { caller_address: CALLER(), udc_address: udc.contract_address })
    );
    let deployed_addr = udc.deploy_contract(ERC20_CLASS_HASH(), SALT, from_zero, ERC20_CALLDATA());
    assert_eq!(expected_addr, deployed_addr);

    // Check event
    assert_only_event_contract_deployed(
        udc.contract_address,
        deployed_addr,
        CALLER(),
        from_zero,
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

fn assert_only_event_contract_deployed(
    contract: ContractAddress,
    address: ContractAddress,
    deployer: ContractAddress,
    from_zero: bool,
    class_hash: ClassHash,
    calldata: Span<felt252>,
    salt: felt252
) {
    let event = utils::pop_log::<UniversalDeployer::Event>(contract).unwrap();
    let expected = UniversalDeployer::Event::ContractDeployed(
        ContractDeployed { address, deployer, from_zero, class_hash, calldata, salt }
    );
    assert!(event == expected);
    utils::assert_no_events_left(contract);
}
