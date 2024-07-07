use core::poseidon::poseidon_hash_span;
use core::starknet::secp256_trait::Secp256PointTrait;
use openzeppelin_account::EthAccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin_account::EthAccountComponent;
use openzeppelin_account::interface::EthPublicKey;
use openzeppelin_account::utils::signature::EthSignature;
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL};
use openzeppelin::tests::utils;
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin_utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::secp256_trait::Secp256Trait;
use starknet::secp256k1::Secp256k1Point;

#[derive(Drop)]
pub(crate) struct SignedTransactionData {
    pub(crate) private_key: u256,
    pub(crate) public_key: EthPublicKey,
    pub(crate) transaction_hash: felt252,
    pub(crate) signature: EthSignature
}

/// This signature was computed using ethers.js.
pub(crate) fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 0x45397ee6ca34cb49060f1c303c6cb7ee2d6123e617601ef3e31ccf7bf5bef1f9,
        public_key: NEW_ETH_PUBKEY(),
        transaction_hash: 0x008f882c63d0396d216d57529fe29ad5e70b6cd51b47bd2458b0a4ccb2ba0957,
        signature: EthSignature {
            r: 0x82bb3efc0554ec181405468f273b0dbf935cca47182b22da78967d0770f7dcc3,
            s: 0x6719fef30c11c74add873e4da0e1234deb69eae6a6bd4daa44b816dc199f3e86,
        }
    }
}

pub(crate) fn NEW_ETH_PUBKEY() -> EthPublicKey {
    Secp256Trait::secp256_ec_new_syscall(
        0x829307f82a1883c2414503ba85fc85037f22c6fc6f80910801f6b01a4131da1e,
        0x2a23f7bddf3715d11767b1247eccc68c89e11b926e2615268db6ad1af8d8da96
    )
        .unwrap()
        .unwrap()
}

pub(crate) fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let name = NAME();
    let symbol = SYMBOL();
    let mut calldata = array![];

    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let address = utils::deploy(DualCaseERC20Mock::TEST_CLASS_HASH, calldata);
    IERC20Dispatcher { contract_address: address }
}

pub(crate) fn get_points() -> (Secp256k1Point, Secp256k1Point) {
    let curve_size = Secp256Trait::<Secp256k1Point>::get_curve_size();
    let point_1 = Secp256Trait::secp256_ec_get_point_from_x_syscall(curve_size, true)
        .unwrap_syscall()
        .unwrap();
    let point_2 = Secp256Trait::secp256_ec_get_point_from_x_syscall(curve_size, false)
        .unwrap_syscall()
        .unwrap();

    (point_1, point_2)
}

pub(crate) fn assert_event_owner_added(contract: ContractAddress, public_key: EthPublicKey) {
    let event = utils::pop_log::<EthAccountComponent::Event>(contract).unwrap();
    let new_owner_guid = get_guid_from_public_key(public_key);
    let expected = EthAccountComponent::Event::OwnerAdded(OwnerAdded { new_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerAdded"));
    indexed_keys.append_serde(new_owner_guid);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_only_event_owner_added(contract: ContractAddress, public_key: EthPublicKey) {
    assert_event_owner_added(contract, public_key);
    utils::assert_no_events_left(contract);
}

pub(crate) fn assert_event_owner_removed(contract: ContractAddress, public_key: EthPublicKey) {
    let event = utils::pop_log::<EthAccountComponent::Event>(contract).unwrap();
    let removed_owner_guid = get_guid_from_public_key(public_key);
    let expected = EthAccountComponent::Event::OwnerRemoved(OwnerRemoved { removed_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerRemoved"));
    indexed_keys.append_serde(removed_owner_guid);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn get_guid_from_public_key(public_key: EthPublicKey) -> felt252 {
    let (x, y) = public_key.get_coordinates().unwrap_syscall();
    poseidon_hash_span(array![x.low.into(), x.high.into(), y.low.into(), y.high.into()].span())
}
