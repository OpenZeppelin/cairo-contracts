use openzeppelin_account::AccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin_account::AccountComponent;
use openzeppelin_account::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::test_utils::constants::{NAME, SYMBOL, NEW_PUBKEY};
use openzeppelin_utils::test_utils;
use starknet::ContractAddress;

#[derive(Drop)]
pub struct SignedTransactionData {
    pub private_key: felt252,
    pub public_key: felt252,
    pub transaction_hash: felt252,
    pub r: felt252,
    pub s: felt252
}

pub fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 1234,
        public_key: NEW_PUBKEY,
        transaction_hash: 0x601d3d2e265c10ff645e1554c435e72ce6721f0ba5fc96f0c650bfc6231191a,
        r: 0x6bc22689efcaeacb9459577138aff9f0af5b77ee7894cdc8efabaf760f6cf6e,
        s: 0x295989881583b9325436851934334faa9d639a2094cd1e2f8691c8a71cd4cdf
    }
}

pub fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let address = test_utils::deploy(DualCaseERC20Mock::TEST_CLASS_HASH, calldata);
    IERC20Dispatcher { contract_address: address }
}


pub fn assert_event_owner_removed(contract: ContractAddress, removed_owner_guid: felt252) {
    let event = test_utils::pop_log::<AccountComponent::Event>(contract).unwrap();
    let expected = AccountComponent::Event::OwnerRemoved(OwnerRemoved { removed_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerRemoved"));
    indexed_keys.append_serde(removed_owner_guid);
    test_utils::assert_indexed_keys(event, indexed_keys.span());
}

pub fn assert_event_owner_added(contract: ContractAddress, new_owner_guid: felt252) {
    let event = test_utils::pop_log::<AccountComponent::Event>(contract).unwrap();
    let expected = AccountComponent::Event::OwnerAdded(OwnerAdded { new_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerAdded"));
    indexed_keys.append_serde(new_owner_guid);
    test_utils::assert_indexed_keys(event, indexed_keys.span());
}

pub fn assert_only_event_owner_added(contract: ContractAddress, new_owner_guid: felt252) {
    assert_event_owner_added(contract, new_owner_guid);
    test_utils::assert_no_events_left(contract);
}
