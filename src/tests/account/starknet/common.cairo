use openzeppelin::account::AccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin::account::AccountComponent;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL, NEW_PUBKEY};
use openzeppelin::tests::utils::events::EventSpyExt;
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::EventSpy;
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

    let address = utils::declare_and_deploy("DualCaseERC20Mock", calldata);
    IERC20Dispatcher { contract_address: address }
}


#[generate_trait]
pub(crate) impl AccountSpyHelpersImpl of AccountSpyHelpers {
    fn assert_event_owner_removed(
        ref self: EventSpy, contract: ContractAddress, removed_owner_guid: felt252
    ) {
        let expected = AccountComponent::Event::OwnerRemoved(OwnerRemoved { removed_owner_guid });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_owner_added(
        ref self: EventSpy, contract: ContractAddress, new_owner_guid: felt252
    ) {
        let expected = AccountComponent::Event::OwnerAdded(OwnerAdded { new_owner_guid });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_owner_added(
        ref self: EventSpy, contract: ContractAddress, new_owner_guid: felt252
    ) {
        self.assert_event_owner_added(contract, new_owner_guid);
        self.assert_no_events_left_from(contract);
    }
}
