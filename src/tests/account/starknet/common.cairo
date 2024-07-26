use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin::account::AccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin::account::AccountComponent;
use openzeppelin_utils::tests_utils::constants::{NAME, SYMBOL, TRANSACTION_HASH};
use openzeppelin_utils::tests_utils::events::EventSpyExt;
use openzeppelin_utils::tests_utils::signing::StarkKeyPair;
use openzeppelin_utils::tests_utils;
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::EventSpy;
use snforge_std::signature::stark_curve::StarkCurveSignerImpl;
use starknet::ContractAddress;

#[derive(Drop)]
pub(crate) struct SignedTransactionData {
    pub(crate) tx_hash: felt252,
    pub(crate) r: felt252,
    pub(crate) s: felt252
}

pub(crate) fn SIGNED_TX_DATA(key_pair: StarkKeyPair) -> SignedTransactionData {
    let tx_hash = TRANSACTION_HASH;
    let (r, s) = key_pair.sign(tx_hash).unwrap();
    SignedTransactionData { tx_hash, r, s }
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

pub(crate) fn get_accept_ownership_signature(
    account_address: ContractAddress, current_public_key: felt252, new_key_pair: StarkKeyPair
) -> Span<felt252> {
    let msg_hash = PoseidonTrait::new()
        .update_with('StarkNet Message')
        .update_with('accept_ownership')
        .update_with(account_address)
        .update_with(current_public_key)
        .finalize();
    let (sig_r, sig_s) = new_key_pair.sign(msg_hash).unwrap();
    array![sig_r, sig_s].span()
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
