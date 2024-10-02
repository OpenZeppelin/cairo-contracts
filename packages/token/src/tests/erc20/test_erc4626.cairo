//use core::num::traits::Bounded;
//use core::num::traits::Zero;
use crate::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
//use crate::erc20::extensions::erc4626::ERC4626Component::{Deposit, Withdraw};
use crate::erc20::extensions::erc4626::ERC4626Component::{ERC4626Impl, ERC4626MetadataImpl, InternalImpl};
use crate::erc20::extensions::erc4626::{ERC4626Component, DefaultConfig};
use crate::tests::mocks::erc4626_mocks::ERC4626Mock;
//use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{NAME, SYMBOL};
//use openzeppelin_testing::events::EventSpyExt;
//use snforge_std::EventSpy;
//use snforge_std::{
//    start_cheat_block_timestamp_global, start_cheat_caller_address, spy_events,
//    start_cheat_chain_id_global, test_address
//};
//use starknet::storage::{StorageMapReadAccess, StoragePointerReadAccess};
use starknet::{ContractAddress, contract_address_const};

fn ASSET_ADDRESS() -> ContractAddress {
    contract_address_const::<'ASSET_ADDRESS'>()
}

//
// Setup
//

type ComponentState = ERC4626Component::ComponentState<ERC4626Mock::ContractState>;

fn CONTRACT_STATE() -> ERC4626Mock::ContractState {
    ERC4626Mock::contract_state_for_testing()
}
fn COMPONENT_STATE() -> ComponentState {
    ERC4626Component::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();

    mock_state.erc20.initializer(NAME(), SYMBOL());
    state.initializer(ASSET_ADDRESS());
    state
}

#[test]
fn test_default_decimals() {
    let state = setup();

    let decimals = state.decimals();
    assert_eq!(decimals, 18);
}
