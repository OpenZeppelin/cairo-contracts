use openzeppelin_finance::vesting::interface::IVestingDispatcher;
use openzeppelin_test_common::erc20::deploy_erc20;
use openzeppelin_testing as utils;
use openzeppelin_utils::serde::SerializedAppend;
use starknet::ContractAddress;

#[derive(Copy, Drop)]
pub(crate) enum VestingStrategy {
    Linear,
    Steps: u64
}

#[derive(Copy, Drop)]
pub(crate) struct TestData {
    pub strategy: VestingStrategy,
    pub total_allocation: u256,
    pub beneficiary: ContractAddress,
    pub start: u64,
    pub duration: u64,
    pub cliff_duration: u64
}

fn deploy_vesting_mock(data: TestData) -> IVestingDispatcher {
    let contract_address = match data.strategy {
        VestingStrategy::Linear => {
            let mut calldata = array![];
            calldata.append_serde(data.beneficiary);
            calldata.append_serde(data.start);
            calldata.append_serde(data.duration);
            calldata.append_serde(data.cliff_duration);
            utils::declare_and_deploy("LinearVestingMock", calldata)
        },
        VestingStrategy::Steps(total_steps) => {
            let mut calldata = array![];
            calldata.append_serde(total_steps);
            calldata.append_serde(data.beneficiary);
            calldata.append_serde(data.start);
            calldata.append_serde(data.duration);
            calldata.append_serde(data.cliff_duration);
            utils::declare_and_deploy("StepsVestingMock", calldata)
        }
    };
    IVestingDispatcher { contract_address }
}

pub(crate) fn setup(data: TestData) -> (IVestingDispatcher, ContractAddress) {
    let vesting = deploy_vesting_mock(data);
    let token = deploy_erc20(vesting.contract_address, data.total_allocation);
    (vesting, token.contract_address)
}
