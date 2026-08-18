use core::num::traits::{Bounded, Zero};
use openzeppelin_interfaces::accounts::{
    ISRC6, ISRC6_ID, MultisigAccountABIDispatcher, MultisigAccountABIDispatcherTrait,
};
use openzeppelin_interfaces::introspection::ISRC5_ID;
use openzeppelin_test_common::mocks::multisig_account::{
    ISignatureCallerMockDispatcher, ISignatureCallerMockDispatcherTrait, MultisigAccountMock,
};
use openzeppelin_test_common::mocks::simple::{ISimpleMockDispatcher, ISimpleMockDispatcherTrait};
use openzeppelin_test_common::multisig_account::get_multisig_signature;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::stark::{KEY_PAIR, KEY_PAIR_2};
use openzeppelin_testing::constants::{
    CALLER, MIN_TRANSACTION_VERSION, OTHER, QUERY_OFFSET, QUERY_VERSION, SALT, TRANSACTION_HASH,
    ZERO,
};
use openzeppelin_testing::signing::{StarkKeyPair, get_stark_keys_from};
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent, spy_events};
use snforge_std::{
    start_cheat_caller_address, start_cheat_signature_global, start_cheat_transaction_hash_global,
    start_cheat_transaction_version_global, test_address,
};
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::storage_access::StorePacking;
use crate::MultisigAccountComponent;
use crate::MultisigAccountComponent::{
    InternalTrait, MultisigImpl, SIGNATURE_VERSION, SRC6CamelOnlyImpl,
};
use crate::multisig_account::storage_utils::{SignersInfo, SignersInfoStorePacking};

type ComponentState = MultisigAccountComponent::ComponentState<MultisigAccountMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    MultisigAccountComponent::component_state_for_testing()
}

fn KEY_PAIR_3() -> StarkKeyPair {
    get_stark_keys_from('PRIVATE_KEY_3')
}

fn DEFAULT_KEY_PAIRS() -> Array<StarkKeyPair> {
    array![KEY_PAIR(), KEY_PAIR_2(), KEY_PAIR_3()]
}

fn public_keys(key_pairs: Span<StarkKeyPair>) -> Array<felt252> {
    let mut result = array![];
    for key_pair in key_pairs {
        result.append((*key_pair).public_key);
    }
    result
}

fn setup_component(quorum: u32, key_pairs: Span<StarkKeyPair>) -> ComponentState {
    let mut state = COMPONENT_STATE();
    let signers = public_keys(key_pairs);
    state.initializer(quorum, signers.span());
    state
}

fn replace_at(
    values: Span<felt252>, index_to_replace: u32, replacement: felt252,
) -> Array<felt252> {
    let mut result = array![];
    for index in 0..values.len() {
        result.append(if index == index_to_replace {
            replacement
        } else {
            *values.at(index)
        });
    }
    result
}

fn constructor_calldata(quorum: u32, signers: Span<felt252>) -> Array<felt252> {
    let mut calldata = array![quorum.into(), signers.len().into()];
    for signer in signers {
        calldata.append(*signer);
    }
    calldata
}

fn deploy_default_account() -> (ContractAddress, MultisigAccountABIDispatcher, felt252) {
    let key_pairs = DEFAULT_KEY_PAIRS();
    let signers = public_keys(key_pairs.span());
    let contract_class = utils::declare_class("MultisigAccountMock");
    let account_address = utils::deploy(contract_class, constructor_calldata(2, signers.span()));
    let dispatcher = MultisigAccountABIDispatcher { contract_address: account_address };
    (account_address, dispatcher, contract_class.class_hash.into())
}

fn start_valid_transaction_context(account_address: ContractAddress) {
    let key_pairs = DEFAULT_KEY_PAIRS();
    let signing_key_pairs = array![*key_pairs.at(0), *key_pairs.at(1)];
    let signature = get_multisig_signature(TRANSACTION_HASH, signing_key_pairs.span());
    start_cheat_signature_global(signature.span());
    start_cheat_transaction_hash_global(TRANSACTION_HASH);
    start_cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    start_cheat_caller_address(account_address, ZERO);
}

fn start_invalid_transaction_context(account_address: ContractAddress) {
    start_valid_transaction_context(account_address);
    start_cheat_transaction_hash_global(TRANSACTION_HASH + 1);
}

fn assert_signers(state: @ComponentState, expected: Span<felt252>) {
    assert_eq!(state.get_signers(), expected);
    for signer in expected {
        assert!(state.is_signer(*signer));
    };
}

//
// Signature parsing and validation
//

#[test]
fn test_signature_exact_quorum_and_all_signers() {
    let key_pairs = DEFAULT_KEY_PAIRS();
    let state = setup_component(2, key_pairs.span());

    let quorum_pairs = array![*key_pairs.at(2), *key_pairs.at(0)];
    let quorum_signature = get_multisig_signature(TRANSACTION_HASH, quorum_pairs.span());
    assert_eq!(state.is_valid_signature(TRANSACTION_HASH, quorum_signature), starknet::VALIDATED);

    let all_signature = get_multisig_signature(TRANSACTION_HASH, key_pairs.span());
    assert_eq!(state.is_valid_signature(TRANSACTION_HASH, all_signature), starknet::VALIDATED);
}

#[test]
fn test_signature_camel_case() {
    let key_pairs = DEFAULT_KEY_PAIRS();
    let state = setup_component(2, key_pairs.span());
    let signing_pairs = array![*key_pairs.at(0), *key_pairs.at(1)];
    let signature = get_multisig_signature(TRANSACTION_HASH, signing_pairs.span());

    assert_eq!(state.isValidSignature(TRANSACTION_HASH, signature.clone()), starknet::VALIDATED);

    let (_, dispatcher, _) = deploy_default_account();
    assert_eq!(
        dispatcher.isValidSignature(TRANSACTION_HASH, signature.clone()), starknet::VALIDATED,
    );
    assert!(dispatcher.isValidSignature(TRANSACTION_HASH + 1, signature).is_zero());
}

#[test]
fn test_parser_rejects_short_and_malformed_lengths_without_panicking() {
    let key_pairs = DEFAULT_KEY_PAIRS();
    let state = setup_component(2, key_pairs.span());

    assert!(state.is_valid_signature(TRANSACTION_HASH, array![]).is_zero());
    assert!(state.is_valid_signature(TRANSACTION_HASH, array![SIGNATURE_VERSION]).is_zero());
    assert!(
        state
            .is_valid_signature(TRANSACTION_HASH, array![SIGNATURE_VERSION, 0, 'TRAILING_DATA'])
            .is_zero(),
    );
    assert!(
        state
            .is_valid_signature(TRANSACTION_HASH, array![SIGNATURE_VERSION, 0, 'TRAILING', 'DATA'])
            .is_zero(),
    );
}

#[test]
fn test_uninitialized_component_rejects_empty_signature_bundle() {
    let state = COMPONENT_STATE();

    assert!(state.is_valid_signature(TRANSACTION_HASH, array![SIGNATURE_VERSION, 0]).is_zero());
}

#[test]
fn test_parser_rejects_version_and_count_mismatch() {
    let key_pairs = DEFAULT_KEY_PAIRS();
    let state = setup_component(2, key_pairs.span());
    let signing_pairs = array![*key_pairs.at(0), *key_pairs.at(1)];
    let signature = get_multisig_signature(TRANSACTION_HASH, signing_pairs.span());

    let wrong_version = replace_at(signature.span(), 0, SIGNATURE_VERSION + 1);
    assert!(state.is_valid_signature(TRANSACTION_HASH, wrong_version).is_zero());

    let wrong_count = replace_at(signature.span(), 1, 3);
    assert!(state.is_valid_signature(TRANSACTION_HASH, wrong_count).is_zero());

    let unconvertible_count = replace_at(signature.span(), 1, -1);
    assert!(state.is_valid_signature(TRANSACTION_HASH, unconvertible_count).is_zero());
}

#[test]
fn test_parser_rejects_below_quorum_and_above_registered_count() {
    let key_pairs = DEFAULT_KEY_PAIRS();
    let state = setup_component(2, key_pairs.span());

    let below_quorum_pairs = array![*key_pairs.at(0)];
    let below_quorum = get_multisig_signature(TRANSACTION_HASH, below_quorum_pairs.span());
    assert!(state.is_valid_signature(TRANSACTION_HASH, below_quorum).is_zero());
    assert!(state.is_valid_signature(TRANSACTION_HASH, array![SIGNATURE_VERSION, 0]).is_zero());

    let too_many = array![SIGNATURE_VERSION, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    assert!(state.is_valid_signature(TRANSACTION_HASH, too_many).is_zero());
}

#[test]
fn test_parser_rejects_unknown_zero_duplicate_and_descending_signers() {
    let registered_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let state = setup_component(2, registered_pairs.span());

    let unknown_pairs = array![KEY_PAIR(), KEY_PAIR_3()];
    let unknown_signature = get_multisig_signature(TRANSACTION_HASH, unknown_pairs.span());
    assert!(state.is_valid_signature(TRANSACTION_HASH, unknown_signature).is_zero());

    let valid_signature = get_multisig_signature(TRANSACTION_HASH, registered_pairs.span());
    let zero_signer = array![
        SIGNATURE_VERSION, 2, 0, *valid_signature.at(3), *valid_signature.at(4),
        *valid_signature.at(5), *valid_signature.at(6), *valid_signature.at(7),
    ];
    assert!(state.is_valid_signature(TRANSACTION_HASH, zero_signer).is_zero());

    let duplicate_signer = array![
        SIGNATURE_VERSION, 2, *valid_signature.at(2), *valid_signature.at(3),
        *valid_signature.at(4), *valid_signature.at(2), *valid_signature.at(3),
        *valid_signature.at(4),
    ];
    assert!(state.is_valid_signature(TRANSACTION_HASH, duplicate_signer).is_zero());

    let descending = array![
        SIGNATURE_VERSION, 2, *valid_signature.at(5), *valid_signature.at(6),
        *valid_signature.at(7), *valid_signature.at(2), *valid_signature.at(3),
        *valid_signature.at(4),
    ];
    assert!(state.is_valid_signature(TRANSACTION_HASH, descending).is_zero());
}

#[test]
fn test_parser_rejects_wrong_hash_and_invalid_signature_parts() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let state = setup_component(2, key_pairs.span());
    let signature = get_multisig_signature(TRANSACTION_HASH, key_pairs.span());

    assert!(state.is_valid_signature(TRANSACTION_HASH + 1, signature).is_zero());

    let signature = get_multisig_signature(TRANSACTION_HASH, key_pairs.span());
    let bad_r = replace_at(signature.span(), 3, 0);
    assert!(state.is_valid_signature(TRANSACTION_HASH, bad_r).is_zero());

    let signature = get_multisig_signature(TRANSACTION_HASH, key_pairs.span());
    let bad_s = replace_at(signature.span(), 4, 0);
    assert!(state.is_valid_signature(TRANSACTION_HASH, bad_s).is_zero());
}

#[test]
fn test_parser_checks_invalid_extra_signature_after_quorum() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let state = setup_component(1, key_pairs.span());
    let signature = get_multisig_signature(TRANSACTION_HASH, key_pairs.span());
    let invalid_extra = replace_at(signature.span(), 6, 0);

    assert!(state.is_valid_signature(TRANSACTION_HASH, invalid_extra).is_zero());
}

#[test]
fn test_removed_signer_signature_is_invalid() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let mut state = setup_component(1, key_pairs.span());
    let removed_pair = array![KEY_PAIR_2()];
    let signature = get_multisig_signature(TRANSACTION_HASH, removed_pair.span());
    assert_eq!(state.is_valid_signature(TRANSACTION_HASH, signature), starknet::VALIDATED);

    start_cheat_caller_address(test_address(), test_address());
    state.remove_signers(1, array![KEY_PAIR_2().public_key].span());

    let signature = get_multisig_signature(TRANSACTION_HASH, removed_pair.span());
    assert!(state.is_valid_signature(TRANSACTION_HASH, signature).is_zero());
}

#[test]
fn test_is_valid_signature_from_nonzero_contract_caller() {
    let (account_address, _, _) = deploy_default_account();
    let caller_address = utils::declare_and_deploy("SignatureCallerMock", array![]);
    let caller = ISignatureCallerMockDispatcher { contract_address: caller_address };
    let key_pairs = DEFAULT_KEY_PAIRS();
    let signing_pairs = array![*key_pairs.at(0), *key_pairs.at(1)];
    let signature = get_multisig_signature(TRANSACTION_HASH, signing_pairs.span());

    assert_eq!(
        caller.call_is_valid_signature(account_address, TRANSACTION_HASH, signature),
        starknet::VALIDATED,
    );
}

#[test]
fn test_starknet_js_golden_invoke_v3_signature() {
    let signers = array![
        0x566d69d8c99f62bc71118399bab25c1f03719463eab8d6a444cd11ece131616,
        0x5f679dacd8278105bd3b84a15548fe84079068276b0e84d6cc093eb5430f063,
        0x6509ed71b354b7125d61b6f3423cbfa33dd7a6b21f0878399a5713118f9e68e,
    ];
    let mut state = COMPONENT_STATE();
    state.initializer(2, signers.span());
    let transaction_hash = 0x211c9566f7eeeb9317a7b9f64596495e7fbc5de41e1749f1068b25014d6f507;
    let signature = array![
        0x1, 0x2, 0x566d69d8c99f62bc71118399bab25c1f03719463eab8d6a444cd11ece131616,
        0x25c78db95a6980b009041b699f4c299f5679f9108765ed984b4e3db08c3a4b6,
        0x5be0428bb190616d6a5d7717ce7dfc1f74133e712879b9c6e49f5940c49566,
        0x5f679dacd8278105bd3b84a15548fe84079068276b0e84d6cc093eb5430f063,
        0x28a401c904d0a95182968cc77a4f0ce104c2dfd917ff04412441beb2ecb296c,
        0xd6e918bb93355eea954d1b11295a0bbfb615b4df8244c85008fcd378770aa1,
    ];

    assert_eq!(state.is_valid_signature(transaction_hash, signature), starknet::VALIDATED);
}

//
// Initialization and signer management
//

#[test]
fn test_initializer_getters_events_and_interfaces() {
    let mut state = COMPONENT_STATE();
    let key_pairs = DEFAULT_KEY_PAIRS();
    let signers = public_keys(key_pairs.span());
    let mut spy = spy_events();

    state.initializer(2, signers.span());

    assert_eq!(state.get_quorum(), 2);
    assert_signers(@state, signers.span());
    spy.assert_event_signer_added(test_address(), *signers.at(0));
    spy.assert_event_signer_added(test_address(), *signers.at(1));
    spy.assert_event_signer_added(test_address(), *signers.at(2));
    spy.assert_event_quorum_updated(test_address(), 0, 2);
    spy.assert_no_events_left_from(test_address());

    let (_, dispatcher, _) = deploy_default_account();
    assert!(dispatcher.supports_interface(ISRC5_ID));
    assert!(dispatcher.supports_interface(ISRC6_ID));
    assert!(!dispatcher.supports_interface('DUMMY_INTERFACE'));
}

#[test]
fn test_initializer_skips_duplicate_signers() {
    let mut state = COMPONENT_STATE();
    let first = KEY_PAIR().public_key;
    let second = KEY_PAIR_2().public_key;
    let signers = array![first, first, second];
    let mut spy = spy_events();

    state.initializer(2, signers.span());

    assert_signers(@state, array![first, second].span());
    spy.assert_event_signer_added(test_address(), first);
    spy.assert_event_signer_added(test_address(), second);
    spy.assert_event_quorum_updated(test_address(), 0, 2);
    spy.assert_no_events_left_from(test_address());
}

#[test]
#[should_panic(expected: 'MultisigAccount: zero quorum')]
fn test_initializer_rejects_zero_quorum() {
    setup_component(0, array![KEY_PAIR()].span());
}

#[test]
#[should_panic(expected: 'MultisigAccount: high quorum')]
fn test_initializer_rejects_quorum_above_unique_signer_count() {
    setup_component(2, array![KEY_PAIR()].span());
}

#[test]
#[should_panic(expected: 'MultisigAccount: zero signer')]
fn test_initializer_rejects_zero_signer() {
    let mut state = COMPONENT_STATE();
    state.initializer(1, array![KEY_PAIR().public_key, 0].span());
}

#[test]
fn test_add_signers_duplicate_empty_and_quorum_branches() {
    let initial_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let mut state = setup_component(1, initial_pairs.span());
    start_cheat_caller_address(test_address(), test_address());
    let new_signer = KEY_PAIR_3().public_key;
    let mut spy = spy_events();

    state.add_signers(2, array![new_signer, new_signer, KEY_PAIR().public_key].span());

    assert_signers(
        @state, array![KEY_PAIR().public_key, KEY_PAIR_2().public_key, new_signer].span(),
    );
    spy.assert_event_signer_added(test_address(), new_signer);
    spy.assert_event_quorum_updated(test_address(), 1, 2);
    spy.assert_no_events_left_from(test_address());

    state.add_signers(3, array![].span());
    assert_eq!(state.get_quorum(), 3);
    spy.assert_only_event_quorum_updated(test_address(), 2, 3);
}

#[test]
#[should_panic(expected: 'MultisigAccount: unauthorized')]
fn test_add_signers_rejects_non_self_caller() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), OTHER);
    state.add_signers(1, array![KEY_PAIR_2().public_key].span());
}

#[test]
#[should_panic(expected: 'MultisigAccount: zero signer')]
fn test_add_signers_rejects_zero_signer() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), test_address());
    state.add_signers(1, array![0].span());
}

#[test]
#[should_panic(expected: 'MultisigAccount: high quorum')]
fn test_add_signers_rejects_high_resulting_quorum() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), test_address());
    state.add_signers(3, array![KEY_PAIR_2().public_key].span());
}

#[test]
fn test_remove_signers_swap_last_unknown_empty_and_quorum_branches() {
    let key_pairs = DEFAULT_KEY_PAIRS();
    let signers = public_keys(key_pairs.span());
    let mut state = setup_component(2, key_pairs.span());
    start_cheat_caller_address(test_address(), test_address());
    let mut spy = spy_events();

    state.remove_signers(2, array![*signers.at(1), 'UNKNOWN_SIGNER'].span());
    assert_signers(@state, array![*signers.at(0), *signers.at(2)].span());
    assert!(!state.is_signer(*signers.at(1)));
    spy.assert_only_event_signer_removed(test_address(), *signers.at(1));

    state.remove_signers(1, array![*signers.at(2)].span());
    assert_signers(@state, array![*signers.at(0)].span());
    spy.assert_event_signer_removed(test_address(), *signers.at(2));
    spy.assert_event_quorum_updated(test_address(), 2, 1);
    spy.assert_no_events_left_from(test_address());

    state.remove_signers(1, array![].span());
    spy.assert_no_events_left_from(test_address());
}

#[test]
fn test_empty_remove_can_change_quorum() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let mut state = setup_component(2, key_pairs.span());
    start_cheat_caller_address(test_address(), test_address());
    let mut spy = spy_events();

    state.remove_signers(1, array![].span());

    assert_eq!(state.get_quorum(), 1);
    spy.assert_only_event_quorum_updated(test_address(), 2, 1);
}

#[test]
#[should_panic(expected: 'MultisigAccount: unauthorized')]
fn test_remove_signers_rejects_non_self_caller() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), OTHER);
    state.remove_signers(1, array![KEY_PAIR().public_key].span());
}

#[test]
#[should_panic(expected: 'MultisigAccount: high quorum')]
fn test_remove_signers_rejects_high_resulting_quorum() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let mut state = setup_component(2, key_pairs.span());
    start_cheat_caller_address(test_address(), test_address());
    state.remove_signers(2, array![KEY_PAIR_2().public_key].span());
}

#[test]
#[should_panic(expected: 'MultisigAccount: zero quorum')]
fn test_remove_signers_rejects_zero_quorum() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let mut state = setup_component(1, key_pairs.span());
    start_cheat_caller_address(test_address(), test_address());
    state.remove_signers(0, array![KEY_PAIR_2().public_key].span());
}

#[test]
fn test_replace_signer_updates_index_membership_and_events() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let mut state = setup_component(2, key_pairs.span());
    start_cheat_caller_address(test_address(), test_address());
    let old_signer = KEY_PAIR().public_key;
    let new_signer = KEY_PAIR_3().public_key;
    let mut spy = spy_events();

    state.replace_signer(old_signer, new_signer);

    assert_signers(@state, array![new_signer, KEY_PAIR_2().public_key].span());
    assert!(!state.is_signer(old_signer));
    spy.assert_event_signer_removed(test_address(), old_signer);
    spy.assert_event_signer_added(test_address(), new_signer);
    spy.assert_no_events_left_from(test_address());
}

#[test]
#[should_panic(expected: 'MultisigAccount: zero signer')]
fn test_replace_signer_rejects_zero_new_signer() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), test_address());
    state.replace_signer(KEY_PAIR().public_key, 0);
}

#[test]
#[should_panic(expected: 'MultisigAccount: already signer')]
fn test_replace_signer_rejects_registered_new_signer() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let mut state = setup_component(1, key_pairs.span());
    start_cheat_caller_address(test_address(), test_address());
    state.replace_signer(KEY_PAIR().public_key, KEY_PAIR_2().public_key);
}

#[test]
#[should_panic(expected: 'MultisigAccount: not signer')]
fn test_replace_signer_rejects_unregistered_old_signer() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), test_address());
    state.replace_signer(KEY_PAIR_2().public_key, KEY_PAIR_3().public_key);
}

#[test]
#[should_panic(expected: 'MultisigAccount: unauthorized')]
fn test_replace_signer_rejects_non_self_caller() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), CALLER);
    state.replace_signer(KEY_PAIR().public_key, KEY_PAIR_2().public_key);
}

#[test]
fn test_change_quorum_and_same_value_event_branch() {
    let key_pairs = array![KEY_PAIR(), KEY_PAIR_2()];
    let mut state = setup_component(1, key_pairs.span());
    start_cheat_caller_address(test_address(), test_address());
    let mut spy = spy_events();

    state.change_quorum(2);
    assert_eq!(state.get_quorum(), 2);
    spy.assert_only_event_quorum_updated(test_address(), 1, 2);

    state.change_quorum(2);
    spy.assert_no_events_left_from(test_address());
}

#[test]
#[should_panic(expected: 'MultisigAccount: unauthorized')]
fn test_change_quorum_rejects_non_self_caller() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), OTHER);
    state.change_quorum(1);
}

#[test]
#[should_panic(expected: 'MultisigAccount: zero quorum')]
fn test_change_quorum_rejects_zero() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), test_address());
    state.change_quorum(0);
}

#[test]
#[should_panic(expected: 'MultisigAccount: high quorum')]
fn test_change_quorum_rejects_value_above_signer_count() {
    let mut state = setup_component(1, array![KEY_PAIR()].span());
    start_cheat_caller_address(test_address(), test_address());
    state.change_quorum(2);
}

#[test]
fn test_mixin_dispatches_all_signer_management_methods() {
    let (account_address, account, _) = deploy_default_account();
    let original_signers = account.get_signers();
    let added_signer = 'ADDED_SIGNER';
    let replacement_signer = 'REPLACEMENT_SIGNER';
    start_cheat_caller_address(account_address, account_address);

    account.add_signers(3, array![added_signer].span());
    assert_eq!(account.get_quorum(), 3);
    assert!(account.is_signer(added_signer));

    account.replace_signer(*original_signers.at(0), replacement_signer);
    assert!(!account.is_signer(*original_signers.at(0)));
    assert!(account.is_signer(replacement_signer));

    account.remove_signers(2, array![*original_signers.at(1)].span());
    assert!(!account.is_signer(*original_signers.at(1)));
    assert_eq!(account.get_signers().len(), 3);

    account.change_quorum(1);
    assert_eq!(account.get_quorum(), 1);
    assert!(account.supports_interface(ISRC6_ID));
}

//
// Account protocol entrypoints and execution
//

#[test]
fn test_validate_invoke_declare_and_deploy() {
    let (account_address, account, class_hash) = deploy_default_account();
    start_valid_transaction_context(account_address);
    let key_pairs = DEFAULT_KEY_PAIRS();
    let signers = public_keys(key_pairs.span());

    assert_eq!(account.__validate__(array![]), starknet::VALIDATED);
    assert_eq!(account.__validate_declare__(class_hash), starknet::VALIDATED);
    assert_eq!(
        account.__validate_deploy__(class_hash, SALT, 2, signers.span()), starknet::VALIDATED,
    );
}

#[test]
#[should_panic(expected: 'MultisigAccount: invalid sig')]
fn test_validate_invoke_rejects_invalid_signature() {
    let (account_address, account, _) = deploy_default_account();
    start_invalid_transaction_context(account_address);
    account.__validate__(array![]);
}

#[test]
#[should_panic(expected: 'MultisigAccount: invalid sig')]
fn test_validate_declare_rejects_invalid_signature() {
    let (account_address, account, class_hash) = deploy_default_account();
    start_invalid_transaction_context(account_address);
    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: 'MultisigAccount: invalid sig')]
fn test_validate_deploy_rejects_invalid_signature() {
    let (account_address, account, class_hash) = deploy_default_account();
    start_invalid_transaction_context(account_address);
    let key_pairs = DEFAULT_KEY_PAIRS();
    let signers = public_keys(key_pairs.span());
    account.__validate_deploy__(class_hash, SALT, 2, signers.span());
}

fn execute_increase_with_version(version: felt252) {
    let (account_address, account, _) = deploy_default_account();
    start_cheat_caller_address(account_address, ZERO);
    start_cheat_transaction_version_global(version);
    let target_address = utils::declare_and_deploy("SimpleMock", array![]);
    let target = ISimpleMockDispatcher { contract_address: target_address };
    let call = Call {
        to: target_address, selector: selector!("increase_balance"), calldata: array![200].span(),
    };

    account.__execute__(array![call]);
    assert_eq!(target.get_balance(), 200);
}

#[test]
fn test_execute_supported_current_future_and_query_versions() {
    execute_increase_with_version(MIN_TRANSACTION_VERSION);
    execute_increase_with_version(MIN_TRANSACTION_VERSION + 1);
    execute_increase_with_version(QUERY_VERSION);
    execute_increase_with_version(QUERY_VERSION + 1);
}

#[test]
fn test_execute_multicall() {
    let (account_address, account, _) = deploy_default_account();
    start_cheat_caller_address(account_address, ZERO);
    start_cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    let target_address = utils::declare_and_deploy("SimpleMock", array![]);
    let target = ISimpleMockDispatcher { contract_address: target_address };
    let first = Call {
        to: target_address, selector: selector!("increase_balance"), calldata: array![300].span(),
    };
    let second = Call {
        to: target_address, selector: selector!("increase_balance"), calldata: array![500].span(),
    };

    account.__execute__(array![first, second]);

    assert_eq!(target.get_balance(), 800);
}

#[test]
#[should_panic(expected: 'MultisigAccount: bad tx version')]
fn test_execute_rejects_version_zero() {
    execute_increase_with_version(MIN_TRANSACTION_VERSION - 1);
}

#[test]
#[should_panic(expected: 'MultisigAccount: bad tx version')]
fn test_execute_rejects_bare_query_offset() {
    execute_increase_with_version(QUERY_OFFSET);
}

#[test]
#[should_panic(expected: 'MultisigAccount: invalid caller')]
fn test_execute_rejects_nonzero_caller() {
    let (account_address, account, _) = deploy_default_account();
    start_cheat_caller_address(account_address, CALLER);
    start_cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    account.__execute__(array![]);
}

//
// Storage packing
//

#[test]
fn test_signers_info_packing_zero_and_known_value() {
    let unpacked_zero: SignersInfo = StorePacking::unpack(0);
    assert_eq!(unpacked_zero.quorum, 0);
    assert_eq!(unpacked_zero.signers_count, 0);

    let info = SignersInfo { quorum: 2, signers_count: 3 };
    let packed = StorePacking::pack(info);
    assert_eq!(packed, 0x200000003);
    let unpacked: SignersInfo = StorePacking::unpack(packed);
    assert_eq!(unpacked.quorum, 2);
    assert_eq!(unpacked.signers_count, 3);
}

#[test]
fn test_signers_info_packing_u32_boundaries() {
    let max: u32 = Bounded::<u32>::MAX;
    let info = SignersInfo { quorum: max, signers_count: max };
    let packed = StorePacking::pack(info);
    let unpacked: SignersInfo = StorePacking::unpack(packed);

    assert_eq!(unpacked.quorum, max);
    assert_eq!(unpacked.signers_count, max);
}

//
// Event helpers
//

#[generate_trait]
impl MultisigAccountSpyHelpersImpl of MultisigAccountSpyHelpers {
    fn assert_event_signer_added(ref self: EventSpy, contract: ContractAddress, signer: felt252) {
        let expected = ExpectedEvent::new().key(selector!("SignerAdded")).key(signer);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_signer_removed(ref self: EventSpy, contract: ContractAddress, signer: felt252) {
        let expected = ExpectedEvent::new().key(selector!("SignerRemoved")).key(signer);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_quorum_updated(
        ref self: EventSpy, contract: ContractAddress, old_quorum: u32, new_quorum: u32,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("QuorumUpdated"))
            .data(old_quorum)
            .data(new_quorum);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_signer_removed(
        ref self: EventSpy, contract: ContractAddress, signer: felt252,
    ) {
        self.assert_event_signer_removed(contract, signer);
        self.assert_no_events_left_from(contract);
    }

    fn assert_only_event_quorum_updated(
        ref self: EventSpy, contract: ContractAddress, old_quorum: u32, new_quorum: u32,
    ) {
        self.assert_event_quorum_updated(contract, old_quorum, new_quorum);
        self.assert_no_events_left_from(contract);
    }
}
