use openzeppelin_account::AccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin_account::AccountComponent;
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL, NEW_PUBKEY};
use openzeppelin::tests::utils;
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin_utils::serde::SerializedAppend;
use starknet::ContractAddress;

#[derive(Drop)]
pub(crate) struct SignedTransactionData {
    pub(crate) private_key: felt252,
    pub(crate) public_key: felt252,
    pub(crate) transaction_hash: felt252,
    pub(crate) r: felt252,
    pub(crate) s: felt252
}

pub(crate) fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 1234,
        public_key: NEW_PUBKEY,
        transaction_hash: 0x601d3d2e265c10ff645e1554c435e72ce6721f0ba5fc96f0c650bfc6231191a,
        r: 0x6bc22689efcaeacb9459577138aff9f0af5b77ee7894cdc8efabaf760f6cf6e,
        s: 0x295989881583b9325436851934334faa9d639a2094cd1e2f8691c8a71cd4cdf
    }
}

pub(crate) fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let address = utils::deploy(DualCaseERC20Mock::TEST_CLASS_HASH, calldata);
    IERC20Dispatcher { contract_address: address }
}


pub(crate) fn assert_event_owner_removed(contract: ContractAddress, removed_owner_guid: felt252) {
    let event = utils::pop_log::<AccountComponent::Event>(contract).unwrap();
    let expected = AccountComponent::Event::OwnerRemoved(OwnerRemoved { removed_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerRemoved"));
    indexed_keys.append_serde(removed_owner_guid);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_event_owner_added(contract: ContractAddress, new_owner_guid: felt252) {
    let event = utils::pop_log::<AccountComponent::Event>(contract).unwrap();
    let expected = AccountComponent::Event::OwnerAdded(OwnerAdded { new_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerAdded"));
    indexed_keys.append_serde(new_owner_guid);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_only_event_owner_added(contract: ContractAddress, new_owner_guid: felt252) {
    assert_event_owner_added(contract, new_owner_guid);
    utils::assert_no_events_left(contract);
}
