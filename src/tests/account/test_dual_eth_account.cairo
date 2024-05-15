use openzeppelin::account::dual_eth_account::{DualCaseEthAccountABI, DualCaseEthAccount};
use openzeppelin::account::interface::{EthAccountABIDispatcherTrait, EthAccountABIDispatcher};
use openzeppelin::account::utils::secp256k1::{
    DebugSecp256k1Point, Secp256k1PointPartialEq, Secp256k1PointSerde
};
use openzeppelin::account::utils::signature::EthSignature;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::account::test_eth_account::NEW_ETH_PUBKEY;
use openzeppelin::tests::account::test_eth_account::SIGNED_TX_DATA;
use openzeppelin::tests::mocks::eth_account_mocks::{
    CamelEthAccountPanicMock, CamelEthAccountMock, SnakeEthAccountMock, SnakeEthAccountPanicMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::ETH_PUBKEY;
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing;

//
// Setup
//

fn setup_snake() -> (DualCaseEthAccount, EthAccountABIDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(ETH_PUBKEY());

    let target = utils::deploy(SnakeEthAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseEthAccount { contract_address: target },
        EthAccountABIDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseEthAccount, EthAccountABIDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(ETH_PUBKEY());

    let target = utils::deploy(CamelEthAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseEthAccount { contract_address: target },
        EthAccountABIDispatcher { contract_address: target }
    )
}

fn setup_non_account() -> DualCaseEthAccount {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseEthAccount { contract_address: target }
}

fn setup_account_panic() -> (DualCaseEthAccount, DualCaseEthAccount) {
    let snake_target = utils::deploy(SnakeEthAccountPanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelEthAccountPanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseEthAccount { contract_address: snake_target },
        DualCaseEthAccount { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
fn test_dual_set_public_key() {
    let (snake_dispatcher, target) = setup_snake();

    testing::set_contract_address(snake_dispatcher.contract_address);

    let new_public_key = NEW_ETH_PUBKEY();
    snake_dispatcher.set_public_key(new_public_key, get_accept_ownership_signature_snake());
    assert_eq!(target.get_public_key(), new_public_key);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.set_public_key(NEW_ETH_PUBKEY(), array![].span());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_set_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.set_public_key(NEW_ETH_PUBKEY(), array![].span());
}

#[test]
fn test_dual_get_public_key() {
    let (snake_dispatcher, _) = setup_snake();
    assert_eq!(snake_dispatcher.get_public_key(), ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_get_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.get_public_key();
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_get_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.get_public_key();
}

#[test]
fn test_dual_is_valid_signature() {
    let (snake_dispatcher, target) = setup_snake();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut serialized_signature = array![];
    data.signature.serialize(ref serialized_signature);

    testing::set_contract_address(snake_dispatcher.contract_address);
    target.set_public_key(data.public_key, get_accept_ownership_signature_snake());

    let is_valid = snake_dispatcher.is_valid_signature(hash, serialized_signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_valid_signature() {
    let hash = 0x0;
    let signature = array![];

    let dispatcher = setup_non_account();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_is_valid_signature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (dispatcher, _) = setup_account_panic();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
fn test_dual_supports_interface() {
    let (snake_dispatcher, _) = setup_snake();
    assert!(snake_dispatcher.supports_interface(ISRC5_ID), "Should implement ISRC5");
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_account();
    dispatcher.supports_interface(ISRC5_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.supports_interface(ISRC5_ID);
}

//
// camelCase target
//

#[test]
fn test_dual_setPublicKey() {
    let (camel_dispatcher, target) = setup_camel();
    let new_public_key = NEW_ETH_PUBKEY();

    testing::set_contract_address(camel_dispatcher.contract_address);

    camel_dispatcher.set_public_key(new_public_key, get_accept_ownership_signature_camel());
    assert_eq!(target.getPublicKey(), new_public_key);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_setPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.set_public_key(NEW_ETH_PUBKEY(), array![].span());
}

#[test]
fn test_dual_getPublicKey() {
    let (camel_dispatcher, _) = setup_camel();
    assert_eq!(camel_dispatcher.get_public_key(), ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_getPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.get_public_key();
}

#[test]
fn test_dual_isValidSignature() {
    let (camel_dispatcher, target) = setup_camel();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut serialized_signature = array![];
    data.signature.serialize(ref serialized_signature);

    testing::set_contract_address(camel_dispatcher.contract_address);
    target.setPublicKey(data.public_key, get_accept_ownership_signature_camel());

    let is_valid = camel_dispatcher.is_valid_signature(hash, serialized_signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_isValidSignature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (_, dispatcher) = setup_account_panic();
    dispatcher.is_valid_signature(hash, signature);
}

//
// Helpers
//

fn get_accept_ownership_signature_snake() -> Span<felt252> {
    let mut output = array![];

    // 0x0601d3dfc94e01d267d2e879ba8063b4341dc231939110bcb9e1211b9bbbaf19 =
    // PoseidonTrait::new()
    //             .update_with('StarkNet Message')
    //             .update_with('accept_ownership')
    //             .update_with(snake_dispatcher.contract_address)
    //             .update_with(ETH_PUBKEY().get_coordinates().unwrap_syscall())
    //             .finalize();

    // This signature was computed using ethers js sdk from the following values:
    // - private_key: 0x45397ee6ca34cb49060f1c303c6cb7ee2d6123e617601ef3e31ccf7bf5bef1f9
    // - public_key:
    //      r: 0x829307f82a1883c2414503ba85fc85037f22c6fc6f80910801f6b01a4131da1e
    //      s: 0x2a23f7bddf3715d11767b1247eccc68c89e11b926e2615268db6ad1af8d8da96
    // - msg_hash: 0x0601d3dfc94e01d267d2e879ba8063b4341dc231939110bcb9e1211b9bbbaf19
    EthSignature {
        r: 0x2ee21d761c9dec6bc855f427ea83b9746b84d3ed7f38cf41e65e9c2d846e9f6c,
        s: 0x586ceb49429f27352cd8237775b28c57002b27f9f1d5418707ac8b88c4794847,
    }
        .serialize(ref output);

    output.span()
}

fn get_accept_ownership_signature_camel() -> Span<felt252> {
    let mut output = array![];

    // 0x07cb1b9d0e9d4c29d2ac505057496b5f3674218c804b17b625f0880c93540dde =
    // PoseidonTrait::new()
    //             .update_with('StarkNet Message')
    //             .update_with('accept_ownership')
    //             .update_with(camel_dispatcher.contract_address)
    //             .update_with(ETH_PUBKEY().get_coordinates().unwrap_syscall())
    //             .finalize();

    // This signature was computed using ethers js sdk from the following values:
    // - private_key: 0x45397ee6ca34cb49060f1c303c6cb7ee2d6123e617601ef3e31ccf7bf5bef1f9
    // - public_key:
    //      r: 0x829307f82a1883c2414503ba85fc85037f22c6fc6f80910801f6b01a4131da1e
    //      s: 0x2a23f7bddf3715d11767b1247eccc68c89e11b926e2615268db6ad1af8d8da96
    // - msg_hash: 0x07cb1b9d0e9d4c29d2ac505057496b5f3674218c804b17b625f0880c93540dde
    EthSignature {
        r: 0xfa72fe7817eaf98fc104183f7f64956196285f7e09f4eecb47c1dcf352a23e13,
        s: 0x4213427c846e9a9be01c91d556f8981f3450918926a5716e865763c9d41bc14b,
    }
        .serialize(ref output);

    output.span()
}
