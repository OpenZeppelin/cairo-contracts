// SPDX-License-Identifier: MIT
use openzeppelin::access::ownable::OwnableComponent::Ownable;
use openzeppelin::finance::vestingwallet::VestingWalletCliffComponent::{
    VestingWalletCliff, InternalImpl
};
use openzeppelin::finance::vestingwallet::VestingWalletCliffComponent;
use openzeppelin::finance::vestingwallet::VestingWalletComponent::VestingWallet;
use openzeppelin::finance::vestingwallet::interface::{
    IVestingWalletCliffDispatcherTrait, IVestingWalletCliffDispatcher
};
use openzeppelin::finance::vestingwallet::interface::{
    IVestingWalletDispatcherTrait, IVestingWalletDispatcher
};
use openzeppelin::finance::vestingwallet::vestingwalletcliff::VestingWalletCliffComponent::InternalTrait;
use openzeppelin::tests::account::test_account::deploy_erc20;
use openzeppelin::tests::mocks::vestingwallet_mocks::vestingwalletcliffmock;
use openzeppelin::tests::utils::constants::{ZERO, OWNER,};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing;
use starknet::{ContractAddress, get_contract_address, get_block_timestamp};

type ComponentState =
    VestingWalletCliffComponent::ComponentState<vestingwalletcliffmock::ContractState>;

fn CONTRACT_STATE() -> vestingwalletcliffmock::ContractState {
    vestingwalletcliffmock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    VestingWalletCliffComponent::component_state_for_testing()
}


fn deploy_vestingwalletcliff() -> IVestingWalletCliffDispatcher {
    let mut calldata = array![];

    calldata.append_serde(OWNER());
    calldata.append_serde(get_block_timestamp());
    calldata.append_serde(60 * 60);
    calldata.append_serde(30 * 60);

    let address = utils::deploy(vestingwalletcliffmock::TEST_CLASS_HASH, calldata);
    IVestingWalletCliffDispatcher { contract_address: address }
}

fn setup() -> (IERC20Dispatcher, IVestingWalletCliffDispatcher) {
    let vestingwalletcliff = deploy_vestingwalletcliff();
    let erc20 = deploy_erc20(vestingwalletcliff.contract_address, 1000);

    return (erc20, vestingwalletcliff);
}

//
// initializer & constructor
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    state
        .initializer(OWNER(), get_block_timestamp() + 60, 60 * 60, get_block_timestamp() + 60 * 31);
    assert_eq!(state.get_cliff(), get_block_timestamp() + 60 * 31);
}

#[test]
fn test_contract() {
    let mut state = CONTRACT_STATE();
    state.vestingwalletcliff.initializer(OWNER(), get_block_timestamp() + 60, 60 * 60, 60 * 30);
    assert_eq!(state.ownable.owner(), OWNER());
}

#[test]
fn test_vestedAmount() {
    let (erc20, vestingwalletcliff) = setup();
    assert_eq!(vestingwalletcliff.get_cliff(), 60 * 30);
    let balance = erc20.balance_of(vestingwalletcliff.contract_address);
    let vestingwallet = IVestingWalletDispatcher {
        contract_address: vestingwalletcliff.contract_address
    };
    assert_eq!(vestingwallet.vestedAmount(erc20.contract_address, get_block_timestamp()), 0);
    assert_eq!(
        vestingwallet.vestedAmount(erc20.contract_address, get_block_timestamp() + 20 * 60), 0
    );
    assert_eq!(
        vestingwallet.vestedAmount(erc20.contract_address, get_block_timestamp() + 60 * 60), balance
    );
    vestingwallet.release_erc20_token(erc20.contract_address);
    assert_eq!(
        vestingwallet.vestedAmount(erc20.contract_address, get_block_timestamp() + 60 * 60), balance
    );
}
