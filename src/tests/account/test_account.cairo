use openzeppelin::account::AccountComponent::{InternalTrait, SRC6CamelOnlyImpl};
use openzeppelin::account::AccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin::account::AccountComponent::{PublicKeyCamelImpl, PublicKeyImpl};
use openzeppelin::account::AccountComponent;
use openzeppelin::account::interface::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin::account::interface::{ISRC6, ISRC6_ID};
use openzeppelin::introspection::interface::{ISRC5, ISRC5_ID};
use openzeppelin::tests::mocks::account_mocks::DualCaseAccountMock;
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin::tests::utils::constants::{
    NAME, SYMBOL, PUBKEY, NEW_PUBKEY, SALT, ZERO, QUERY_OFFSET, QUERY_VERSION, MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::contract_address_const;
use starknet::testing;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252
}

fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 1234,
        public_key: NEW_PUBKEY,
        transaction_hash: 0x601d3d2e265c10ff645e1554c435e72ce6721f0ba5fc96f0c650bfc6231191a,
        r: 0x6bc22689efcaeacb9459577138aff9f0af5b77ee7894cdc8efabaf760f6cf6e,
        s: 0x295989881583b9325436851934334faa9d639a2094cd1e2f8691c8a71cd4cdf
    }
}

//
// Constants
//

fn CLASS_HASH() -> felt252 {
    DualCaseAccountMock::TEST_CLASS_HASH
}

fn ACCOUNT_ADDRESS() -> ContractAddress {
    contract_address_const::<0x111111>()
}

//
// Setup
//

type ComponentState = AccountComponent::ComponentState<DualCaseAccountMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseAccountMock::ContractState {
    DualCaseAccountMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    AccountComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(PUBKEY);
    utils::drop_event(ZERO());
    state
}

fn setup_dispatcher(data: Option<@SignedTransactionData>) -> AccountABIDispatcher {
    testing::set_version(MIN_TRANSACTION_VERSION);

    let mut calldata = array![];
    if data.is_some() {
        let data = data.unwrap();
        testing::set_signature(array![*data.r, *data.s].span());
        testing::set_transaction_hash(*data.transaction_hash);

        calldata.append(*data.public_key);
    } else {
        calldata.append(PUBKEY);
    }
    let address = utils::deploy(CLASS_HASH(), calldata);
    AccountABIDispatcher { contract_address: address }
}

fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let address = utils::deploy(DualCaseERC20Mock::TEST_CLASS_HASH, calldata);
    IERC20Dispatcher { contract_address: address }
}

//
// is_valid_signature & isValidSignature
//

#[test]
fn test_is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];

    state._set_public_key(data.public_key);

    let is_valid = state.is_valid_signature(hash, good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let is_valid = state.is_valid_signature(hash, bad_signature);
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

#[test]
fn test_isValidSignature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];

    state._set_public_key(data.public_key);

    let is_valid = state.isValidSignature(hash, good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let is_valid = state.isValidSignature(hash, bad_signature);
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

//
// Entry points
//

#[test]
fn test_validate_deploy() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    let is_valid = account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_length() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![];

    signature.append(0x1);
    testing::set_signature(signature.span());

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_empty_signature() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());
    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
fn test_validate_declare() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    let is_valid = account.__validate_declare__(CLASS_HASH());
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_length() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![];

    signature.append(0x1);
    testing::set_signature(signature.span());

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_empty_signature() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());

    account.__validate_declare__(CLASS_HASH());
}

fn test_execute_with_version(version: Option<felt252>) {
    let data = SIGNED_TX_DATA();
    let account = setup_dispatcher(Option::Some(@data));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient = contract_address_const::<0x123>();

    // Craft call and add to calls array
    let mut calldata = array![];
    let amount: u256 = 200;
    calldata.append_serde(recipient);
    calldata.append_serde(amount);
    let call = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata.span()
    };
    let mut calls = array![];
    calls.append(call);

    // Handle version for test
    if version.is_some() {
        testing::set_version(version.unwrap());
    }

    // Execute
    let ret = account.__execute__(calls);

    // Assert that the transfer was successful
    assert_eq!(erc20.balance_of(account.contract_address), 800, "Should have remainder");
    assert_eq!(erc20.balance_of(recipient), amount, "Should have transferred");

    // Test return value
    let mut call_serialized_retval = *ret.at(0);
    let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
    assert!(call_retval.unwrap());
}

#[test]
fn test_execute() {
    test_execute_with_version(Option::None(()));
}

#[test]
fn test_execute_future_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION + 1));
}

#[test]
fn test_execute_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION));
}

#[test]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_query_version() {
    test_execute_with_version(Option::Some(QUERY_OFFSET));
}

#[test]
fn test_execute_future_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION + 1));
}

#[test]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION - 1));
}

#[test]
fn test_validate() {
    let calls = array![];
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    let is_valid = account.__validate__(calls);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_invalid() {
    let calls = array![];
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
fn test_multicall() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = contract_address_const::<0x123>();
    let recipient2 = contract_address_const::<0x456>();
    let mut calls = array![];

    // Craft call1
    let mut calldata1 = array![];
    let amount1: u256 = 300;
    calldata1.append_serde(recipient1);
    calldata1.append_serde(amount1);
    let call1 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata1.span()
    };

    // Craft call2
    let mut calldata2 = array![];
    let amount2: u256 = 500;
    calldata2.append_serde(recipient2);
    calldata2.append_serde(amount2);
    let call2 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata2.span()
    };

    // Bundle calls and exeute
    calls.append(call1);
    calls.append(call2);
    let ret = account.__execute__(calls);

    // Assert that the transfers were successful
    assert_eq!(erc20.balance_of(account.contract_address), 200, "Should have remainder");
    assert_eq!(erc20.balance_of(recipient1), 300, "Should have transferred from call1");
    assert_eq!(erc20.balance_of(recipient2), 500, "Should have transferred from call2");

    // Test return values
    let mut call1_serialized_retval = *ret.at(0);
    let mut call2_serialized_retval = *ret.at(1);

    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    assert!(call1_retval.unwrap());

    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert!(call2_retval.unwrap());
}

#[test]
fn test_multicall_zero_calls() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let mut calls = array![];

    let response = account.__execute__(calls);
    assert!(response.is_empty());
}

#[test]
#[should_panic(expected: ('Account: invalid caller',))]
fn test_account_called_from_contract() {
    let state = setup();
    let calls = array![];
    let caller = contract_address_const::<0x123>();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    state.__execute__(calls);
}

//
// set_public_key & get_public_key
//

#[test]
fn test_public_key_setter_and_getter() {
    let mut state = COMPONENT_STATE();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    state._set_public_key(PUBKEY);
    utils::drop_event(ACCOUNT_ADDRESS());
    let public_key = state.get_public_key();
    assert_eq!(public_key, PUBKEY);

    // Set key
    state.set_public_key(NEW_PUBKEY, get_accept_ownership_signature());

    assert_event_owner_removed(ACCOUNT_ADDRESS(), PUBKEY);
    assert_only_event_owner_added(ACCOUNT_ADDRESS(), NEW_PUBKEY);

    let public_key = state.get_public_key();
    assert_eq!(public_key, NEW_PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_public_key_setter_different_account() {
    let mut state = COMPONENT_STATE();
    let caller = contract_address_const::<0x123>();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    state.set_public_key(NEW_PUBKEY, array![].span());
}

//
// setPublicKey & getPublicKey
//

#[test]
fn test_public_key_setter_and_getter_camel() {
    let mut state = COMPONENT_STATE();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    state._set_public_key(PUBKEY);
    utils::drop_event(ACCOUNT_ADDRESS());
    let public_key = state.getPublicKey();
    assert_eq!(public_key, PUBKEY);

    // Set key
    state.setPublicKey(NEW_PUBKEY, get_accept_ownership_signature());

    assert_event_owner_removed(ACCOUNT_ADDRESS(), PUBKEY);
    assert_only_event_owner_added(ACCOUNT_ADDRESS(), NEW_PUBKEY);

    let public_key = state.getPublicKey();
    assert_eq!(public_key, NEW_PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_public_key_setter_different_account_camel() {
    let mut state = COMPONENT_STATE();
    let caller = contract_address_const::<0x123>();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    state.setPublicKey(NEW_PUBKEY, array![].span());
}

//
// Test internals
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer(PUBKEY);
    assert_only_event_owner_added(ZERO(), PUBKEY);

    let public_key = state.get_public_key();
    assert_eq!(public_key, PUBKEY);

    let supports_isrc5 = mock_state.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);

    let supports_isrc6 = mock_state.supports_interface(ISRC6_ID);
    assert!(supports_isrc6);
}

#[test]
fn test_assert_only_self_true() {
    let mut state = COMPONENT_STATE();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());
    state.assert_only_self();
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_assert_only_self_false() {
    let mut state = COMPONENT_STATE();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    let other = contract_address_const::<0x4567>();
    testing::set_caller_address(other);
    state.assert_only_self();
}

#[test]
fn test_assert_valid_new_owner() {
    let mut state = setup();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    state.assert_valid_new_owner(PUBKEY, NEW_PUBKEY, get_accept_ownership_signature());
}


#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_assert_valid_new_owner_invalid_signature() {
    let mut state = setup();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    let bad_signature = array![
        0x2ce8fbcf8a793ee5b2a57254dc96863b696698943e3bc7845285f3851336318,
        0x6009f5720649ff1ceb0aba44f85bec3572c81aecb9d2dada7c0cc70b791debe
    ];
    state.assert_valid_new_owner(PUBKEY, NEW_PUBKEY, bad_signature.span());
}

#[test]
fn test__is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];
    let mut invalid_length_signature = array![0x987];

    state._set_public_key(data.public_key);

    let is_valid = state._is_valid_signature(hash, good_signature.span());
    assert!(is_valid);

    let is_not_valid = !state._is_valid_signature(hash, bad_signature.span());
    assert!(is_not_valid);

    let is_not_valid = !state._is_valid_signature(hash, invalid_length_signature.span());
    assert!(is_not_valid);
}

#[test]
fn test__set_public_key() {
    let mut state = COMPONENT_STATE();
    state._set_public_key(PUBKEY);

    assert_only_event_owner_added(ZERO(), PUBKEY);

    let public_key = state.get_public_key();
    assert_eq!(public_key, PUBKEY);
}

//
// Helpers
//

fn get_accept_ownership_signature() -> Span<felt252> {
    // 0x7b3d2ce38c132a36e692f6e809b518276d091513af3baf0e94ce2abceee3632 =
    // PoseidonTrait::new()
    //             .update_with('StarkNet Message')
    //             .update_with('accept_ownership')
    //             .update_with(ACCOUNT_ADDRESS())
    //             .update_with(PUBKEY)
    //             .finalize();

    // This signature was computed using starknet js sdk from the following values:
    // - private_key: '1234'
    // - public_key: 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7
    // - msg_hash: 0x7b3d2ce38c132a36e692f6e809b518276d091513af3baf0e94ce2abceee3632
    array![
        0x1ce8fbcf8a793ee5b2a57254dc96863b696698943e3bc7845285f3851336318,
        0x6009f5720649ff1ceb0aba44f85bec3572c81aecb9d2dada7c0cc70b791debe
    ]
        .span()
}

fn assert_event_owner_removed(contract: ContractAddress, removed_owner_guid: felt252) {
    let event = utils::pop_log::<AccountComponent::Event>(contract).unwrap();
    let expected = AccountComponent::Event::OwnerRemoved(OwnerRemoved { removed_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerRemoved"));
    indexed_keys.append_serde(removed_owner_guid);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_owner_added(contract: ContractAddress, new_owner_guid: felt252) {
    let event = utils::pop_log::<AccountComponent::Event>(contract).unwrap();
    let expected = AccountComponent::Event::OwnerAdded(OwnerAdded { new_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerAdded"));
    indexed_keys.append_serde(new_owner_guid);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_owner_added(contract: ContractAddress, new_owner_guid: felt252) {
    assert_event_owner_added(contract, new_owner_guid);
    utils::assert_no_events_left(contract);
}
