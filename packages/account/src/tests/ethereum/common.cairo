use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use core::poseidon::poseidon_hash_span;
use core::starknet::secp256_trait::Secp256PointTrait;
use openzeppelin_account::EthAccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin_account::EthAccountComponent;
use openzeppelin_account::interface::EthPublicKey;
use openzeppelin_account::utils::signature::EthSignature;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::test_utils as utils;
use openzeppelin_utils::test_utils::constants::TRANSACTION_HASH;
use openzeppelin_utils::test_utils::constants::{NAME, SYMBOL};
use openzeppelin_utils::test_utils::events::EventSpyExt;
use openzeppelin_utils::test_utils::signing::{Secp256k1KeyPair, Secp256k1SerializedSigning};
use snforge_std::EventSpy;
use snforge_std::signature::secp256k1_curve::Secp256k1CurveSignerImpl;
use starknet::{ContractAddress, SyscallResultTrait};

#[derive(Drop)]
pub struct SignedTransactionData {
    pub private_key: u256,
    pub public_key: EthPublicKey,
    pub tx_hash: felt252,
    pub signature: EthSignature
}

pub fn SIGNED_TX_DATA(key_pair: Secp256k1KeyPair) -> SignedTransactionData {
    let tx_hash = TRANSACTION_HASH;
    let (r, s) = key_pair.sign(tx_hash.into()).unwrap();
    SignedTransactionData {
        private_key: key_pair.secret_key,
        public_key: key_pair.public_key,
        tx_hash,
        signature: EthSignature { r, s }
    }
}

pub fn get_accept_ownership_signature(
    account_address: ContractAddress, current_owner: EthPublicKey, new_key_pair: Secp256k1KeyPair
) -> Span<felt252> {
    let msg_hash: u256 = PoseidonTrait::new()
        .update_with('StarkNet Message')
        .update_with('accept_ownership')
        .update_with(account_address)
        .update_with(current_owner.get_coordinates().unwrap_syscall())
        .finalize()
        .into();

    new_key_pair.serialized_sign(msg_hash).span()
}

pub fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let address = utils::declare_and_deploy("DualCaseERC20Mock", calldata);
    IERC20Dispatcher { contract_address: address }
}


#[generate_trait]
pub impl EthAccountSpyHelpersImpl of EthAccountSpyHelpers {
    fn assert_event_owner_removed(
        ref self: EventSpy, contract: ContractAddress, public_key: EthPublicKey
    ) {
        let removed_owner_guid = get_guid_from_public_key(public_key);
        let expected = EthAccountComponent::Event::OwnerRemoved(
            OwnerRemoved { removed_owner_guid }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_owner_added(
        ref self: EventSpy, contract: ContractAddress, public_key: EthPublicKey
    ) {
        let new_owner_guid = get_guid_from_public_key(public_key);
        let expected = EthAccountComponent::Event::OwnerAdded(OwnerAdded { new_owner_guid });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_owner_added(
        ref self: EventSpy, contract: ContractAddress, public_key: EthPublicKey
    ) {
        self.assert_event_owner_added(contract, public_key);
        self.assert_no_events_left_from(contract);
    }
}

fn get_guid_from_public_key(public_key: EthPublicKey) -> felt252 {
    let (x, y) = public_key.get_coordinates().unwrap_syscall();
    poseidon_hash_span(array![x.low.into(), x.high.into(), y.low.into(), y.high.into()].span())
}
