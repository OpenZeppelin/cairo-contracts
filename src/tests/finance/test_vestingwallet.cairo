// SPDX-License-Identifier: MIT
use openzeppelin::access::ownable::OwnableComponent::Ownable;
use openzeppelin::finance::vestingwallet::VestingWalletComponent::{VestingWallet, InternalImpl};
use openzeppelin::finance::vestingwallet::VestingWalletComponent;
use openzeppelin::finance::vestingwallet::interface::{
    IVestingWalletDispatcherTrait, IVestingWalletDispatcher
};
use openzeppelin::finance::vestingwallet::vestingwallet::VestingWalletComponent::InternalTrait;
use openzeppelin::tests::account::test_account::deploy_erc20;
use openzeppelin::tests::mocks::vestingwallet_mocks::vestingwalletmock;
use openzeppelin::tests::utils::constants::{ZERO, OWNER,};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing;
use starknet::{ContractAddress, get_contract_address, get_block_timestamp};

type ComponentState = VestingWalletComponent::ComponentState<vestingwalletmock::ContractState>;

fn CONTRACT_STATE() -> vestingwalletmock::ContractState {
    vestingwalletmock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    VestingWalletComponent::component_state_for_testing()
}

fn deploy_vestingwallet() -> IVestingWalletDispatcher {
    let mut calldata = array![];

    calldata.append_serde(OWNER());
    calldata.append_serde(get_block_timestamp());
    calldata.append_serde(60 * 60);

    let address = utils::deploy(vestingwalletmock::TEST_CLASS_HASH, calldata);
    IVestingWalletDispatcher { contract_address: address }
}

fn setup() -> (IERC20Dispatcher, IVestingWalletDispatcher) {
    let vestingwallet = deploy_vestingwallet();
    let erc20 = deploy_erc20(vestingwallet.contract_address, 1000);

    return (erc20, vestingwallet);
}

//
// initializer & constructor
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    state.initializer(OWNER(), get_block_timestamp() + 60, 60 * 60);
    assert_eq!(state.get_start(), (get_block_timestamp() + 60).into());
    assert_eq!(state.get_duration(), 60 * 60);
    assert_eq!(state.get_end(), (get_block_timestamp() + 60 * 61).into());
}

#[test]
fn test_contract() {
    let mut state = CONTRACT_STATE();
    state.vestingwallet.initializer(OWNER(), get_block_timestamp() + 60, 60 * 60);
    assert_eq!(state.ownable.owner(), OWNER());
}

#[test]
fn test_get_erc20_releasable() {
    let (erc20, vestingwallet) = setup();
    assert_eq!(vestingwallet.get_erc20_releasable(erc20.contract_address), 0);
    testing::set_block_timestamp(get_block_timestamp() + 30 * 60);
    let balance = erc20.balance_of(vestingwallet.contract_address);
    assert_eq!(vestingwallet.get_erc20_releasable(erc20.contract_address), balance / 2);
}

#[test]
fn test_release_erc20_token() {
    let (erc20, vestingwallet) = setup();
    testing::set_block_timestamp(get_block_timestamp() + 10 * 60);
    assert_eq!(vestingwallet.release_erc20_token(erc20.contract_address), true);
}

#[test]
fn test_get_erc20_released() {
    let (erc20, vestingwallet) = setup();
    let balance = erc20.balance_of(vestingwallet.contract_address);
    testing::set_block_timestamp(get_block_timestamp() + 30 * 60);
    vestingwallet.release_erc20_token(erc20.contract_address);
    assert_eq!(vestingwallet.get_erc20_released(erc20.contract_address), balance / 2);
    assert_eq!(vestingwallet.get_erc20_releasable(erc20.contract_address), 0);
}

#[test]
fn test_vestedAmount() {
    let (erc20, vestingwallet) = setup();
    let balance = erc20.balance_of(vestingwallet.contract_address);
    assert_eq!(vestingwallet.vestedAmount(erc20.contract_address, get_block_timestamp()), 0);
    assert_eq!(
        vestingwallet.vestedAmount(erc20.contract_address, get_block_timestamp() + 30 * 60),
        balance / 2
    );
    assert_eq!(
        vestingwallet.vestedAmount(erc20.contract_address, get_block_timestamp() + 60 * 60), balance
    );
    testing::set_block_timestamp(get_block_timestamp() + 30 * 60);
    vestingwallet.release_erc20_token(erc20.contract_address);
    assert_eq!(
        vestingwallet.vestedAmount(erc20.contract_address, get_block_timestamp() + 60 * 60), balance
    );
}
