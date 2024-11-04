use MultisigComponent::InternalTrait;
use core::num::traits::Zero;
use crate::multisig::MultisigComponent::{MultisigImpl, InternalImpl};
use crate::multisig::{MultisigComponent, TransactionID, TransactionState};
use openzeppelin_test_common::mocks::multisig::IMultisigTargetDispatcherTrait;
use openzeppelin_test_common::mocks::multisig::{MultisigWalletMock, IMultisigTargetDispatcher};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{OTHER, ALICE, BOB, CHARLIE, SALT, BLOCK_NUMBER};
use openzeppelin_testing::events::EventSpyExt;
use snforge_std::{EventSpy, spy_events, test_address};
use snforge_std::{start_cheat_caller_address, start_cheat_block_number_global};
use starknet::account::Call;
use starknet::{ContractAddress, contract_address_const};

//
// Setup
//

type ComponentState = MultisigComponent::ComponentState<MultisigWalletMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    MultisigComponent::component_state_for_testing()
}

fn DEFAULT_DATA() -> (u8, Span<ContractAddress>) {
    let signers = array![ALICE(), BOB(), CHARLIE()];
    let quorum = signers.len() - 1;
    (quorum.try_into().unwrap(), signers.span())
}

fn MOCK_ADDRESS() -> ContractAddress {
    contract_address_const::<'MOCK_ADDRESS'>()
}

fn setup_component(quorum: u8, signers: Span<ContractAddress>) -> ComponentState {
    start_cheat_block_number_global(BLOCK_NUMBER);
    let mut state = COMPONENT_STATE();
    state.initializer(quorum, signers);
    state
}

fn deploy_mock() -> IMultisigTargetDispatcher {
    let contract_address = MOCK_ADDRESS();
    utils::declare_and_deploy_at("MultisigTarget", contract_address, array![]);
    IMultisigTargetDispatcher { contract_address }
}

//
// Submit tx
//

#[test]
fn test_submit_tx() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();

    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt = 0;
    let expected_id = state.hash_transaction(to, selector, calldata, salt);
    assert_tx_state(expected_id, TransactionState::NotFound);

    let signer = ALICE();
    start_cheat_caller_address(contract_address, signer);

    let id = state.submit_transaction(to, selector, calldata, salt);
    assert_eq!(id, expected_id);
    assert_eq!(state.get_submitted_block(id), BLOCK_NUMBER);
    assert_tx_state(id, TransactionState::Pending);
    spy.assert_only_event_tx_submitted(contract_address, id, signer);
}

#[test]
fn test_submit_tx_custom_salt() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();

    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt = SALT;
    let expected_id = state.hash_transaction(to, selector, calldata, salt);
    assert_tx_state(expected_id, TransactionState::NotFound);

    let signer = ALICE();
    start_cheat_caller_address(contract_address, signer);

    let id = state.submit_transaction(to, selector, calldata, salt);
    assert_eq!(id, expected_id);
    assert_eq!(state.get_submitted_block(id), BLOCK_NUMBER);
    assert_tx_state(id, TransactionState::Pending);
    spy.assert_event_call_salt(contract_address, id, salt);
    spy.assert_event_tx_submitted(contract_address, id, signer);
}

#[test]
fn test_submit_same_tx_again_different_salt() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();

    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt_1 = 0;
    let expected_id_1 = state.hash_transaction(to, selector, calldata, salt_1);
    let salt_2 = SALT;
    let expected_id_2 = state.hash_transaction(to, selector, calldata, salt_2);
    assert!(expected_id_1 != expected_id_2);

    let signer = ALICE();
    start_cheat_caller_address(contract_address, signer);

    let id_1 = state.submit_transaction(to, selector, calldata, salt_1);
    assert_eq!(id_1, expected_id_1);
    assert_tx_state(id_1, TransactionState::Pending);
    spy.assert_only_event_tx_submitted(contract_address, id_1, signer);

    let id_2 = state.submit_transaction(to, selector, calldata, salt_2);
    assert_eq!(id_2, expected_id_2);
    assert_tx_state(id_2, TransactionState::Pending);
    spy.assert_event_call_salt(contract_address, id_2, salt_2);
    spy.assert_only_event_tx_submitted(contract_address, id_2, signer);
}

#[test]
fn test_submit_tx_batch() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();

    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();
    let salt = 0;
    let expected_id = state.hash_transaction_batch(calls, salt);
    assert_tx_state(expected_id, TransactionState::NotFound);

    let signer = ALICE();
    start_cheat_caller_address(contract_address, signer);

    let id = state.submit_transaction_batch(calls, salt);
    assert_eq!(id, expected_id);
    assert_eq!(state.get_submitted_block(id), BLOCK_NUMBER);
    assert_tx_state(id, TransactionState::Pending);
    spy.assert_only_event_tx_submitted(contract_address, id, signer);
}

#[test]
fn test_submit_tx_batch_custom_salt() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();

    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();
    let salt = SALT;
    let expected_id = state.hash_transaction_batch(calls, salt);
    assert_tx_state(expected_id, TransactionState::NotFound);

    let signer = ALICE();
    start_cheat_caller_address(contract_address, signer);

    let id = state.submit_transaction_batch(calls, salt);
    assert_eq!(id, expected_id);
    assert_eq!(state.get_submitted_block(id), BLOCK_NUMBER);
    assert_tx_state(id, TransactionState::Pending);
    spy.assert_event_call_salt(contract_address, id, salt);
    spy.assert_event_tx_submitted(contract_address, id, signer);
}

#[test]
fn test_submit_same_tx_batch_different_salt() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();

    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();
    let salt_1 = 0;
    let expected_id_1 = state.hash_transaction_batch(calls, salt_1);
    let salt_2 = SALT;
    let expected_id_2 = state.hash_transaction_batch(calls, salt_2);
    assert!(expected_id_1 != expected_id_2);

    let signer = ALICE();
    start_cheat_caller_address(contract_address, signer);

    let id_1 = state.submit_transaction_batch(calls, salt_1);
    assert_eq!(id_1, expected_id_1);
    assert_tx_state(id_1, TransactionState::Pending);
    spy.assert_only_event_tx_submitted(contract_address, id_1, signer);

    let id_2 = state.submit_transaction_batch(calls, salt_2);
    assert_eq!(id_2, expected_id_2);
    assert_tx_state(id_2, TransactionState::Pending);
    spy.assert_event_call_salt(contract_address, id_2, salt_2);
    spy.assert_event_tx_submitted(contract_address, id_2, signer);
}

#[test]
#[should_panic(expected: 'Multisig: not a signer')]
fn test_cannot_submit_tx_not_signer() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);

    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let signer = OTHER();
    start_cheat_caller_address(test_address(), signer);
    state.submit_transaction(to, selector, calldata, 0);
}

#[test]
#[should_panic(expected: 'Multisig: not a signer')]
fn test_cannot_submit_tx_batch_not_signer() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);

    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();
    let signer = OTHER();
    start_cheat_caller_address(test_address(), signer);
    state.submit_transaction_batch(calls, 0);
}

#[test]
#[should_panic(expected: 'Multisig: tx already exists')]
fn test_cannot_submit_tx_twice() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);

    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let signer = ALICE();
    start_cheat_caller_address(test_address(), signer);
    state.submit_transaction(to, selector, calldata, 0);
    state.submit_transaction(to, selector, calldata, 0);
}

#[test]
#[should_panic(expected: 'Multisig: tx already exists')]
fn test_cannot_submit_tx_batch_twice() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);

    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();
    let signer = ALICE();
    start_cheat_caller_address(test_address(), signer);
    state.submit_transaction_batch(calls, 0);
    state.submit_transaction_batch(calls, 0);
}

//
// Confirm tx
//

#[test]
fn test_confirm_tx() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));

    // Submit by Alice
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, 0);

    // Confirm by Bob
    spy.drop_all_events();
    start_cheat_caller_address(contract_address, BOB());
    assert_eq!(state.is_confirmed_by(id, BOB()), false);
    state.confirm_transaction(id);
    assert_eq!(state.is_confirmed_by(id, BOB()), true);
    assert_tx_state(id, TransactionState::Pending);
    assert_eq!(state.get_transaction_confirmations(id), 1);
    spy.assert_only_event_tx_confirmed(contract_address, id, BOB(), 1);

    // Confirm by Charlie
    start_cheat_caller_address(contract_address, CHARLIE());
    assert_eq!(state.is_confirmed_by(id, CHARLIE()), false);
    state.confirm_transaction(id);
    assert_eq!(state.is_confirmed_by(id, CHARLIE()), true);
    assert_tx_state(id, TransactionState::Confirmed);
    assert_eq!(state.get_transaction_confirmations(id), 2);
    spy.assert_only_event_tx_confirmed(contract_address, id, CHARLIE(), 2);
}

#[test]
fn test_confirmed_status_changed_when_quorum_increased() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));

    // Submit by Alice
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, 0);

    // Confirm by Bob
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);

    // Confirm by Charlie
    start_cheat_caller_address(contract_address, CHARLIE());
    state.confirm_transaction(id);

    assert_tx_state(id, TransactionState::Confirmed);
    state._change_quorum(quorum + 1);
    assert_tx_state(id, TransactionState::Pending);
}

#[test]
fn test_confirmed_status_changed_when_quorum_reduced() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));

    // Submit by Alice
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, 0);

    // Confirm by Bob
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);

    assert_tx_state(id, TransactionState::Pending);
    state._change_quorum(quorum - 1);
    assert_tx_state(id, TransactionState::Confirmed);
}

#[test]
fn test_confirm_tx_batch() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();

    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();

    // Submit by Alice
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction_batch(calls, 0);
    assert_tx_state(id, TransactionState::Pending);
    assert_eq!(state.get_transaction_confirmations(id), 0);
    spy.drop_all_events();

    // Confirm by Bob
    start_cheat_caller_address(contract_address, BOB());
    assert_eq!(state.is_confirmed_by(id, BOB()), false);
    state.confirm_transaction(id);
    assert_eq!(state.is_confirmed_by(id, BOB()), true);
    assert_tx_state(id, TransactionState::Pending);
    assert_eq!(state.get_transaction_confirmations(id), 1);
    spy.assert_only_event_tx_confirmed(contract_address, id, BOB(), 1);

    // Confirm by Charlie
    start_cheat_caller_address(contract_address, CHARLIE());
    assert_eq!(state.is_confirmed_by(id, CHARLIE()), false);
    state.confirm_transaction(id);
    assert_eq!(state.is_confirmed_by(id, CHARLIE()), true);
    assert_tx_state(id, TransactionState::Confirmed);
    assert_eq!(state.get_transaction_confirmations(id), 2);
    spy.assert_only_event_tx_confirmed(contract_address, id, CHARLIE(), 2);
}

#[test]
#[should_panic(expected: 'Multisig: tx not found')]
fn test_cannot_confirm_nonexistent_tx() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();

    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let id = state.hash_transaction(to, selector, calldata, 0);

    start_cheat_caller_address(contract_address, ALICE());
    state.confirm_transaction(id);
}

#[test]
#[should_panic(expected: 'Multisig: not a signer')]
fn test_cannot_confirm_tx_not_signer() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();

    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let id = state.hash_transaction(to, selector, calldata, 0);
    start_cheat_caller_address(contract_address, ALICE());
    state.submit_transaction(to, selector, calldata, 0);

    start_cheat_caller_address(contract_address, OTHER());
    state.confirm_transaction(id);
}

#[test]
#[should_panic(expected: 'Multisig: already confirmed')]
fn test_cannot_confirm_tx_twice() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();

    // Submit by Alice
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let id = state.hash_transaction(to, selector, calldata, 0);
    start_cheat_caller_address(contract_address, ALICE());
    state.submit_transaction(to, selector, calldata, 0);

    // Confirm by Bob
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);
    assert_eq!(state.is_confirmed_by(id, BOB()), true);
    assert_eq!(state.get_transaction_confirmations(id), 1);

    // Try to confirm again by Bob
    state.confirm_transaction(id);
}

//
// Revoke confirmation
//

#[test]
fn test_revoke_confirmation() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let contract_address = test_address();

    // Submit by Alice
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, 0);

    // Confirm by Bob
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);

    // Confirm by Charlie
    start_cheat_caller_address(contract_address, CHARLIE());
    state.confirm_transaction(id);

    // Revoke confirmation by Charlie
    spy.drop_all_events();
    assert_tx_state(id, TransactionState::Confirmed);
    assert_eq!(state.is_confirmed_by(id, CHARLIE()), true);
    assert_eq!(state.get_transaction_confirmations(id), 2);
    state.revoke_confirmation(id);
    assert_tx_state(id, TransactionState::Pending);
    assert_eq!(state.is_confirmed_by(id, CHARLIE()), false);
    assert_eq!(state.get_transaction_confirmations(id), 1);
    spy.assert_only_event_confirmation_revoked(contract_address, id, CHARLIE(), 1);
}

#[test]
#[should_panic(expected: 'Multisig: has not confirmed')]
fn test_cannot_revoke_confirmation_has_not_confirmed() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);

    // Submit by Alice
    start_cheat_caller_address(test_address(), ALICE());
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let id = state.submit_transaction(to, selector, calldata, 0);

    // Revoke confirmation by Bob
    state.revoke_confirmation(id);
}

#[test]
#[should_panic(expected: 'Multisig: tx not found')]
fn test_cannot_revoke_confirmation_nonexistent_tx() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);

    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let id = state.hash_transaction(to, selector, calldata, 0);
    state.revoke_confirmation(id);
}

//
// Execute tx
//

#[test]
fn test_execute_tx() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let mut spy = spy_events();
    let mock = deploy_mock();
    let contract_address = test_address();

    // Submit
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt = 0;
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, salt);

    // Confirm
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);
    start_cheat_caller_address(contract_address, CHARLIE());
    state.confirm_transaction(id);

    // Check state before
    assert_eq!(mock.get_current_sum(), 0);
    assert_tx_state(id, TransactionState::Confirmed);

    // Execute
    spy.drop_all_events();
    start_cheat_caller_address(contract_address, ALICE());
    state.execute_transaction(to, selector, calldata, salt);

    // Check state after
    assert_eq!(mock.get_current_sum(), 42);
    assert_tx_state(id, TransactionState::Executed);
    spy.assert_only_event_tx_executed(contract_address, id);
}

#[test]
fn test_execute_tx_batch() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    let mut spy = spy_events();
    let mock = deploy_mock();
    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();
    let salt = 0;

    // Submit
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction_batch(calls, salt);

    // Confirm
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);
    start_cheat_caller_address(contract_address, CHARLIE());
    state.confirm_transaction(id);

    // Check state before
    assert_eq!(mock.get_current_sum(), 0);
    assert_tx_state(id, TransactionState::Confirmed);

    // Execute
    spy.drop_all_events();
    start_cheat_caller_address(contract_address, ALICE());
    state.execute_transaction_batch(calls, salt);

    // Check state after
    assert_eq!(mock.get_current_sum(), 100);
    assert_tx_state(id, TransactionState::Executed);
    spy.assert_only_event_tx_executed(contract_address, id);
}

#[test]
#[should_panic(expected: 'Multisig: not a signer')]
fn test_cannot_execute_not_signer() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt = 0;

    // Submit
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, salt);

    // Confirm
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);
    start_cheat_caller_address(contract_address, CHARLIE());
    state.confirm_transaction(id);

    // Try to execute
    start_cheat_caller_address(contract_address, OTHER());
    state.execute_transaction(to, selector, calldata, salt);
}

#[test]
#[should_panic(expected: 'Multisig: not a signer')]
fn test_cannot_execute_batch_not_signer() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();
    let salt = 0;

    // Submit
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction_batch(calls, salt);

    // Confirm
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);
    start_cheat_caller_address(contract_address, CHARLIE());
    state.confirm_transaction(id);

    // Try to execute
    start_cheat_caller_address(contract_address, OTHER());
    state.execute_transaction_batch(calls, salt);
}

#[test]
#[should_panic(expected: 'Multisig: tx not confirmed')]
fn test_cannot_execute_not_confirmed() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt = 0;

    // Submit
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, salt);

    // Confirm once
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);

    // Execute
    state.execute_transaction(to, selector, calldata, salt);
}

#[test]
#[should_panic(expected: 'Multisig: tx not confirmed')]
fn test_cannot_execute_batch_not_confirmed() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt = 0;

    // Submit
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, salt);

    // Confirm once
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);

    // Execute
    state.execute_transaction(to, selector, calldata, salt);
}

#[test]
#[should_panic(expected: 'Multisig: tx already executed')]
fn test_cannot_execute_twice() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt = 0;
    deploy_mock();

    // Submit
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, salt);

    // Confirm
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);
    start_cheat_caller_address(contract_address, CHARLIE());
    state.confirm_transaction(id);

    // Execute 1st time
    state.execute_transaction(to, selector, calldata, salt);

    // Try to execute 2nd time
    state.execute_transaction(to, selector, calldata, salt);
}

#[test]
#[should_panic(expected: 'Multisig: tx already executed')]
fn test_cannot_execute_batch_twice() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let contract_address = test_address();
    deploy_mock();

    // Submit
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    let salt = 0;
    start_cheat_caller_address(contract_address, ALICE());
    let id = state.submit_transaction(to, selector, calldata, salt);

    // Confirm
    start_cheat_caller_address(contract_address, BOB());
    state.confirm_transaction(id);
    start_cheat_caller_address(contract_address, CHARLIE());
    state.confirm_transaction(id);

    // Execute 1st time
    state.execute_transaction(to, selector, calldata, salt);

    // Try to execute 2nd time
    state.execute_transaction(to, selector, calldata, salt);
}

//
// hash_transaction
//

#[test]
fn test_tx_hash_depends_on_salt() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let Call { to, selector, calldata } = build_call(MockCall::AddNumber(42));
    start_cheat_caller_address(test_address(), ALICE());

    let mut salt = 0;
    while salt != 10 {
        let id_from_hash = state.hash_transaction(to, selector, calldata, salt);
        let id = state.submit_transaction(to, selector, calldata, salt);
        assert_eq!(id_from_hash, id);
        salt += 1;
    };
}

#[test]
fn test_tx_batch_hash_depends_on_salt() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    let calls = array![
        build_call(MockCall::AddNumber(42)),
        build_call(MockCall::AddNumber(18)),
        build_call(MockCall::AddNumber(40))
    ]
        .span();
    start_cheat_caller_address(test_address(), ALICE());

    let mut salt = 0;
    while salt != 10 {
        let id_from_hash = state.hash_transaction_batch(calls, salt);
        let id = state.submit_transaction_batch(calls, salt);
        assert_eq!(id_from_hash, id);
        salt += 1;
    };
}

#[test]
fn test_tx_hash_depends_on_calldata() {
    let (quorum, signers) = DEFAULT_DATA();
    let mut state = setup_component(quorum, signers);
    start_cheat_caller_address(test_address(), ALICE());

    let mut num = 0;
    while num != 10 {
        let Call { to, selector, calldata } = build_call(MockCall::AddNumber(num));
        let id_from_hash = state.hash_transaction(to, selector, calldata, SALT);
        let id = state.submit_transaction(to, selector, calldata, SALT);
        assert_eq!(id_from_hash, id);
        num += 1;
    };
}

#[test]
fn test_tx_hash_depends_on_selector() {
    let (quorum, signers) = DEFAULT_DATA();
    let state = setup_component(quorum, signers);

    let to = MOCK_ADDRESS();
    let empty_calldata = array![].span();
    let id_1 = state.hash_transaction(to, selector!("selector_1"), empty_calldata, SALT);
    let id_2 = state.hash_transaction(to, selector!("selector_2"), empty_calldata, SALT);
    let id_3 = state.hash_transaction(to, selector!("selector_3"), empty_calldata, SALT);
    assert!(id_1 != id_2);
    assert!(id_2 != id_3);
    assert!(id_1 != id_3);
}

#[test]
fn test_tx_hash_depends_on_to_address() {
    let (quorum, signers) = DEFAULT_DATA();
    let state = setup_component(quorum, signers);

    let Call { to: _, selector, calldata } = build_call(MockCall::AddNumber(42));
    let id_1 = state.hash_transaction(ALICE(), selector, calldata, SALT);
    let id_2 = state.hash_transaction(BOB(), selector, calldata, SALT);
    let id_3 = state.hash_transaction(CHARLIE(), selector, calldata, SALT);
    assert!(id_1 != id_2);
    assert!(id_2 != id_3);
    assert!(id_1 != id_3);
}

//
// Helpers
//

#[derive(Copy, Drop)]
enum MockCall {
    AddNumber: felt252,
    FailingFn,
    BadSelector
}

fn build_call(call: MockCall) -> Call {
    let (selector, calldata) = match call {
        MockCall::AddNumber(number) => (selector!("add_number"), array![number]),
        MockCall::FailingFn => (selector!("failing_function"), array![]),
        MockCall::BadSelector => (selector!("bad_selector"), array![]),
    };
    Call { to: MOCK_ADDRESS(), selector, calldata: calldata.span() }
}

fn assert_tx_state(id: TransactionID, expected_state: TransactionState) {
    let state = COMPONENT_STATE();
    let tx_state = state.get_transaction_state(id);
    let block = state.get_submitted_block(id);
    let is_confirmed = state.is_confirmed(id);
    let is_executed = state.is_executed(id);
    let tx_confirmations = state.get_transaction_confirmations(id);

    assert_eq!(tx_state, expected_state);
    match expected_state {
        TransactionState::NotFound => {
            assert!(block.is_zero());
            assert!(!is_confirmed);
            assert!(!is_executed);
            assert!(tx_confirmations.is_zero());
        },
        TransactionState::Pending => {
            assert!(block.is_non_zero());
            assert!(!is_confirmed);
            assert!(!is_executed);
            assert!(tx_confirmations < state.get_quorum());
        },
        TransactionState::Confirmed => {
            assert!(block.is_non_zero());
            assert!(is_confirmed);
            assert!(!is_executed);
            assert!(tx_confirmations >= state.get_quorum());
        },
        TransactionState::Executed => {
            assert!(block.is_non_zero());
            assert!(is_confirmed);
            assert!(is_executed);
            assert!(tx_confirmations >= state.get_quorum());
        }
    };
}

fn assert_signers_list(expected_signers: Array<ContractAddress>) {
    let state = COMPONENT_STATE();
    assert_eq!(state.get_signers().len(), expected_signers.len());
    for signer in expected_signers {
        assert!(state.is_signer(signer));
    };
}

//
// Events
//

#[generate_trait]
impl MultisigSpyHelpersImpl of MultisigSpyHelpers {
    //
    // SignerAdded
    //

    fn assert_event_signer_added(
        ref self: EventSpy, contract: ContractAddress, signer: ContractAddress
    ) {
        let expected = MultisigComponent::Event::SignerAdded(
            MultisigComponent::SignerAdded { signer }
        );
        self.assert_emitted_single(contract, expected);
    }

    //
    // SignerRemoved
    //

    fn assert_event_signer_removed(
        ref self: EventSpy, contract: ContractAddress, signer: ContractAddress
    ) {
        let expected = MultisigComponent::Event::SignerRemoved(
            MultisigComponent::SignerRemoved { signer }
        );
        self.assert_emitted_single(contract, expected);
    }

    //
    // QuorumUpdated
    //

    fn assert_event_quorum_updated(
        ref self: EventSpy, contract: ContractAddress, old_quorum: u8, new_quorum: u8
    ) {
        let expected = MultisigComponent::Event::QuorumUpdated(
            MultisigComponent::QuorumUpdated { old_quorum, new_quorum }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_quorum_updated(
        ref self: EventSpy, contract: ContractAddress, old_quorum: u8, new_quorum: u8
    ) {
        self.assert_event_quorum_updated(contract, old_quorum, new_quorum);
        self.assert_no_events_left_from(contract);
    }

    //
    // TransactionSubmitted
    //

    fn assert_event_tx_submitted(
        ref self: EventSpy, contract: ContractAddress, id: TransactionID, signer: ContractAddress
    ) {
        let expected = MultisigComponent::Event::TransactionSubmitted(
            MultisigComponent::TransactionSubmitted { id, signer }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_tx_submitted(
        ref self: EventSpy, contract: ContractAddress, id: TransactionID, signer: ContractAddress
    ) {
        self.assert_event_tx_submitted(contract, id, signer);
        self.assert_no_events_left_from(contract);
    }

    //
    // TransactionConfirmed
    //

    fn assert_event_tx_confirmed(
        ref self: EventSpy,
        contract: ContractAddress,
        id: TransactionID,
        signer: ContractAddress,
        total_confirmations: u8
    ) {
        let expected = MultisigComponent::Event::TransactionConfirmed(
            MultisigComponent::TransactionConfirmed { id, signer, total_confirmations }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_tx_confirmed(
        ref self: EventSpy,
        contract: ContractAddress,
        id: TransactionID,
        signer: ContractAddress,
        total_confirmations: u8
    ) {
        self.assert_event_tx_confirmed(contract, id, signer, total_confirmations);
        self.assert_no_events_left_from(contract);
    }

    //
    // ConfirmationRevoked
    //

    fn assert_event_confirmation_revoked(
        ref self: EventSpy,
        contract: ContractAddress,
        id: TransactionID,
        signer: ContractAddress,
        total_confirmations: u8
    ) {
        let expected = MultisigComponent::Event::ConfirmationRevoked(
            MultisigComponent::ConfirmationRevoked { id, signer, total_confirmations }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_confirmation_revoked(
        ref self: EventSpy,
        contract: ContractAddress,
        id: TransactionID,
        signer: ContractAddress,
        total_confirmations: u8
    ) {
        self.assert_event_confirmation_revoked(contract, id, signer, total_confirmations);
        self.assert_no_events_left_from(contract);
    }

    //
    // TransactionExecuted
    //

    fn assert_event_tx_executed(ref self: EventSpy, contract: ContractAddress, id: TransactionID) {
        let expected = MultisigComponent::Event::TransactionExecuted(
            MultisigComponent::TransactionExecuted { id }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_tx_executed(
        ref self: EventSpy, contract: ContractAddress, id: TransactionID
    ) {
        self.assert_event_tx_executed(contract, id);
        self.assert_no_events_left_from(contract);
    }

    //
    // CallSalt
    //

    fn assert_event_call_salt(
        ref self: EventSpy, contract: ContractAddress, id: TransactionID, salt: felt252
    ) {
        let expected = MultisigComponent::Event::CallSalt(MultisigComponent::CallSalt { id, salt });
        self.assert_emitted_single(contract, expected);
    }
}
