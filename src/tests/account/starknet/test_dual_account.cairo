use openzeppelin::account::dual_account::{DualCaseAccountABI, DualCaseAccount};
use openzeppelin::account::interface::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::account::starknet::common::SIGNED_TX_DATA;
use openzeppelin::tests::mocks::account_mocks::{
    CamelAccountPanicMock, CamelAccountMock, SnakeAccountMock, SnakeAccountPanicMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{PUBKEY, NEW_PUBKEY};
use openzeppelin::tests::utils;
use starknet::testing;

//
// Setup
//

fn setup_snake() -> (DualCaseAccount, AccountABIDispatcher) {
    let mut calldata = array![PUBKEY];
    let target = utils::deploy(SnakeAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccount { contract_address: target },
        AccountABIDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseAccount, AccountABIDispatcher) {
    let mut calldata = array![PUBKEY];
    let target = utils::deploy(CamelAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseAccount { contract_address: target },
        AccountABIDispatcher { contract_address: target }
    )
}

fn setup_non_account() -> DualCaseAccount {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseAccount { contract_address: target }
}

fn setup_account_panic() -> (DualCaseAccount, DualCaseAccount) {
    let snake_target = utils::deploy(SnakeAccountPanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelAccountPanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseAccount { contract_address: snake_target },
        DualCaseAccount { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
fn test_dual_set_public_key() {
    let (snake_dispatcher, target) = setup_snake();

    testing::set_contract_address(snake_dispatcher.contract_address);

    snake_dispatcher.set_public_key(NEW_PUBKEY, get_accept_ownership_signature_snake());

    let public_key = target.get_public_key();
    assert_eq!(public_key, NEW_PUBKEY);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.set_public_key(NEW_PUBKEY, array![].span());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_set_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.set_public_key(NEW_PUBKEY, array![].span());
}

#[test]
fn test_dual_get_public_key() {
    let (snake_dispatcher, _) = setup_snake();
    let public_key = snake_dispatcher.get_public_key();
    assert_eq!(public_key, PUBKEY);
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
    let mut signature = array![data.r, data.s];

    testing::set_contract_address(snake_dispatcher.contract_address);
    target.set_public_key(data.public_key, get_accept_ownership_signature_snake());

    let is_valid = snake_dispatcher.is_valid_signature(hash, signature);
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
    let supports_isrc5 = snake_dispatcher.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);
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

    testing::set_contract_address(camel_dispatcher.contract_address);
    camel_dispatcher.set_public_key(NEW_PUBKEY, get_accept_ownership_signature_camel());

    let public_key = target.getPublicKey();
    assert_eq!(public_key, NEW_PUBKEY);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_setPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.set_public_key(NEW_PUBKEY, array![].span());
}

#[test]
fn test_dual_getPublicKey() {
    let (camel_dispatcher, _) = setup_camel();
    let public_key = camel_dispatcher.get_public_key();
    assert_eq!(public_key, PUBKEY);
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
    let signature = array![data.r, data.s];

    testing::set_contract_address(camel_dispatcher.contract_address);
    target.setPublicKey(data.public_key, get_accept_ownership_signature_camel());

    let is_valid = camel_dispatcher.is_valid_signature(hash, signature);
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
    // 0x26a14ae81fad8adcb81337e49fd68ac44d508cfca09c4a6167c71e85759e98d =
    // PoseidonTrait::new()
    //             .update_with('StarkNet Message')
    //             .update_with('accept_ownership')
    //             .update_with(snake_dispatcher.contract_address)
    //             .update_with(PUBKEY)
    //             .finalize();

    // This signature was computed using starknet js sdk from the following values:
    // - private_key: '1234'
    // - public_key: 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7
    // - msg_hash: 0x26a14ae81fad8adcb81337e49fd68ac44d508cfca09c4a6167c71e85759e98d
    array![
        0x14de5d99a3a43bc7e8e0ddf8ff72fab172798ac3dd7bd858d4f6f489a2a4bcb,
        0x88dd5cb7f27a8932a5c6d226b486830e952e3d9e78996e7ca2315afa9c0be2
    ]
        .span()
}

fn get_accept_ownership_signature_camel() -> Span<felt252> {
    // 0x1e2acd787c2778bebfbf4d8770fdc0834db1576b5fd190f35afae5a6f7f469f =
    // PoseidonTrait::new()
    //             .update_with('StarkNet Message')
    //             .update_with('accept_ownership')
    //             .update_with(camel_dispatcher.contract_address)
    //             .update_with(PUBKEY)
    //             .finalize();

    // This signature was computed using starknet js sdk from the following values:
    // - private_key: '1234'
    // - public_key: 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7
    // - msg_hash: 0x1e2acd787c2778bebfbf4d8770fdc0834db1576b5fd190f35afae5a6f7f469f
    array![
        0xd0eab69db72a46ee0fb39c833cfaec035ca809eb884285d0e603262f15e0dd,
        0x768e984a96d5f731c3cf1660c5a00f508f3d99d8240bf3ba4c3e69561a545d1
    ]
        .span()
}
