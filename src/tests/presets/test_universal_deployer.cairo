use openzeppelin::presets::universal_deployer::UniversalDeployer::ContractDeployed;
use openzeppelin::presets::universal_deployer::UniversalDeployer;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL, SUPPLY, SALT, CALLER, RECIPIENT};
use openzeppelin::tests::utils::events::EventSpyExt;
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::deployments::{DeployerInfo, calculate_contract_address_from_udc};
use openzeppelin::utils::interfaces::{
    IUniversalDeployerDispatcher, IUniversalDeployerDispatcherTrait
};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{EventSpy, spy_events, declare, start_cheat_caller_address};
use starknet::{ClassHash, ContractAddress};


fn ERC20_CALLDATA() -> Span<felt252> {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(SUPPLY);
    calldata.append_serde(RECIPIENT());
    calldata.span()
}

fn deploy_udc() -> IUniversalDeployerDispatcher {
    let mut calldata = array![];

    let address = utils::declare_and_deploy("UniversalDeployer", calldata);
    IUniversalDeployerDispatcher { contract_address: address }
}

#[test]
fn test_deploy_from_zero() {
    let udc = deploy_udc();
    let caller = CALLER();

    // Deploy args
    let erc20_class_hash = utils::declare_class("DualCaseERC20Mock").class_hash;
    let salt = SALT;
    let from_zero = true;
    let erc20_calldata = ERC20_CALLDATA();

    let mut spy = spy_events();
    start_cheat_caller_address(udc.contract_address, caller);

    // Check address
    let expected_addr = calculate_contract_address_from_udc(
        salt, erc20_class_hash, erc20_calldata, Option::None
    );
    let deployed_addr = udc.deploy_contract(erc20_class_hash, salt, from_zero, erc20_calldata);
    assert_eq!(expected_addr, deployed_addr);

    // Check event
    spy
        .assert_event_contract_deployed(
            udc.contract_address,
            deployed_addr,
            caller,
            from_zero,
            erc20_class_hash,
            erc20_calldata,
            salt
        );

    // Check deployment
    let erc20 = IERC20Dispatcher { contract_address: deployed_addr };
    let total_supply = erc20.total_supply();
    assert_eq!(total_supply, SUPPLY);
}

#[test]
fn test_deploy_not_from_zero() {
    let udc = deploy_udc();
    let caller = CALLER();

    // Deploy args
    let erc20_class_hash = utils::declare_class("DualCaseERC20Mock").class_hash;
    let salt = SALT;
    let from_zero = false;
    let erc20_calldata = ERC20_CALLDATA();

    let mut spy = spy_events();
    start_cheat_caller_address(udc.contract_address, caller);

    // Check address
    let expected_addr = calculate_contract_address_from_udc(
        salt,
        erc20_class_hash,
        erc20_calldata,
        Option::Some(DeployerInfo { caller_address: caller, udc_address: udc.contract_address })
    );
    let deployed_addr = udc.deploy_contract(erc20_class_hash, salt, from_zero, erc20_calldata);
    assert_eq!(expected_addr, deployed_addr);

    // Check event
    spy
        .assert_event_contract_deployed(
            udc.contract_address,
            deployed_addr,
            caller,
            from_zero,
            erc20_class_hash,
            erc20_calldata,
            salt
        );

    // Check deployment
    let erc20 = IERC20Dispatcher { contract_address: deployed_addr };
    let total_supply = erc20.total_supply();
    assert_eq!(total_supply, SUPPLY);
}

//
// Helpers
//

#[generate_trait]
pub(crate) impl UniversalDeployerHelpersImpl of UniversalDeployerSpyHelpers {
    fn assert_event_contract_deployed(
        ref self: EventSpy,
        contract: ContractAddress,
        address: ContractAddress,
        deployer: ContractAddress,
        from_zero: bool,
        class_hash: ClassHash,
        calldata: Span<felt252>,
        salt: felt252
    ) {
        let expected = UniversalDeployer::Event::ContractDeployed(
            ContractDeployed { address, deployer, from_zero, class_hash, calldata, salt }
        );
        self.assert_emitted_single(contract, expected);
    }
}
