use core::hash::{HashStateExTrait, HashStateTrait};
use core::pedersen::PedersenTrait;
use openzeppelin_test_common::mocks::counter::{ICounterDispatcher, ICounterDispatcherTrait};
use openzeppelin_test_common::mocks::legacy_account::ILegacyAccountDispatcher;
use openzeppelin_test_common::mocks::observer::{
    CallInfo, IObserverDispatcher, IObserverDispatcherTrait, ObserverComponent,
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::ZERO;
use openzeppelin_testing::constants::stark::KEY_PAIR;
use openzeppelin_testing::events::EventSpyQueueDebug;
use openzeppelin_testing::signing::StarkSerializedSigning;
use openzeppelin_testing::{AsAddressTrait, EventSpyExt, EventSpyQueue as EventSpy, spy_events};
use snforge_std::{
    start_cheat_chain_id, start_cheat_chain_id_global, start_cheat_max_fee_global,
    start_cheat_transaction_version_global,
};
use starknet::account::Call;
use starknet::{ContractAddress, SyscallResultTrait};
use crate::interfaces::{MetaTransactionV0ABIDispatcher, MetaTransactionV0ABIDispatcherTrait};

//
// Setup
//

const TX_VERSION_3: felt252 = 3;
const TX_VERSION_0: felt252 = 0;
const MAX_FEE: u128 = 0;
const EXECUTE_SELECTOR: felt252 = selector!("__execute__");
const ACCOUNT: ContractAddress = 'ACCOUNT'.as_address();
const COUNTER: ContractAddress = 'COUNTER'.as_address();
// const CHAIN_ID: felt252 = 'SN_SEPOLIA';
const CHAIN_ID: felt252 = 'SN_MAIN';

fn setup_dispatchers(
    exp_tx_hash: felt252, exp_chain_id: felt252,
) -> (MetaTransactionV0ABIDispatcher, ILegacyAccountDispatcher, ICounterDispatcher) {
    let contract_address = utils::declare_and_deploy("MetaTransactionV0", array![]);
    let meta_tx_dispatcher = MetaTransactionV0ABIDispatcher { contract_address };

    utils::declare_and_deploy_at("LegacyAccountMock", ACCOUNT, array![KEY_PAIR().public_key]);
    let account_dispatcher = ILegacyAccountDispatcher { contract_address: ACCOUNT };

    utils::declare_and_deploy_at("CounterMock", COUNTER, array![]);
    let counter_dispatcher = ICounterDispatcher { contract_address: COUNTER };

    (meta_tx_dispatcher, account_dispatcher, counter_dispatcher)
}

//
// Tests
//

#[test]
fn test_meta_tx_v0_context_update() {
    // Prepare calldata and signature
    let (incr_1, incr_2, incr_3): (u64, u64, u64) = (1, 19, 22);
    let calls: Span<Call> = array![
        Call {
            to: COUNTER, selector: selector!("increase_by"), calldata: array![incr_1.into()].span(),
        },
        Call {
            to: COUNTER, selector: selector!("increase_by"), calldata: array![incr_2.into()].span(),
        },
        Call {
            to: COUNTER, selector: selector!("increase_by"), calldata: array![incr_3.into()].span(),
        },
    ]
        .span();
    let mut calldata = array![];
    calls.serialize(ref calldata);
    let calldata = calldata.span();
    let tx_hash = compute_invoke_v0_tx_hash(ACCOUNT, EXECUTE_SELECTOR, calldata);
    let signature = KEY_PAIR().serialized_sign(tx_hash).span();

    // Setup
    let (meta_tx_dispatcher, account_dispatcher, counter_dispatcher) = setup_dispatchers(
        tx_hash, CHAIN_ID,
    );
    println!("--------------------------------");
    println!("Initial chain id: {:?}", starknet::get_tx_info().unbox().chain_id);
    setup_execution_context();
    println!("Chain id after setup: {:?}", starknet::get_tx_info().unbox().chain_id);

    // Check initial state of counter
    let counter = counter_dispatcher.get_current_value();
    assert_eq!(counter, 0);

    // Execute meta tx
    let mut spy = spy_events();
    meta_tx_dispatcher
        .execute_meta_tx_v0(
            account_dispatcher.contract_address, EXECUTE_SELECTOR, calldata, signature,
        )
        .unwrap_syscall();

    // Print calls and events
    print_external_calls_to(ACCOUNT, 'ACCOUNT');
    print_external_calls_to(COUNTER, 'COUNTER');
    println!("--------------------------------");
    spy.print_all_events();

    // assert_external_calls_to(ACCOUNT, array![
    //     CallInfo { caller: ZERO, tx_version: TX_VERSION_0, chain_id: CHAIN_ID, tx_hash },
    // ]);
    // assert_external_calls_to(COUNTER, array![
    //     CallInfo { caller: ACCOUNT, tx_version: TX_VERSION_0, chain_id: CHAIN_ID, tx_hash },
    //     CallInfo { caller: ACCOUNT, tx_version: TX_VERSION_0, chain_id: CHAIN_ID, tx_hash },
    //     CallInfo { caller: ACCOUNT, tx_version: TX_VERSION_0, chain_id: CHAIN_ID, tx_hash },
    // ]);

    // Check events
    spy.assert_event_external_call(ACCOUNT, ZERO, TX_VERSION_0, CHAIN_ID, tx_hash);
    spy.assert_event_external_call(COUNTER, ACCOUNT, TX_VERSION_0, CHAIN_ID, tx_hash);
    spy.assert_event_external_call(COUNTER, ACCOUNT, TX_VERSION_0, CHAIN_ID, tx_hash);
    spy.assert_event_external_call(COUNTER, ACCOUNT, TX_VERSION_0, CHAIN_ID, tx_hash);
    spy.assert_no_events_left_from(COUNTER);

    // Check final state of counter
    let expected_counter = incr_1 + incr_2 + incr_3;
    let counter = counter_dispatcher.get_current_value();
    assert_eq!(counter, expected_counter);
}

//
// Helpers
//

fn setup_execution_context() {
    start_cheat_transaction_version_global(TX_VERSION_3);
    start_cheat_max_fee_global(MAX_FEE);
    start_cheat_chain_id_global(CHAIN_ID);
    start_cheat_chain_id(ACCOUNT, CHAIN_ID);
}

fn compute_invoke_v0_tx_hash(
    contract_address: ContractAddress, selector: felt252, calldata: Span<felt252>,
) -> felt252 {
    let mut calldata_hash = PedersenTrait::new(0);
    for elem in calldata {
        calldata_hash = calldata_hash.update_with(*elem);
    }
    let calldata_hash = calldata_hash.update_with(calldata.len()).finalize();
    PedersenTrait::new(0)
        .update_with('invoke')
        .update_with(TX_VERSION_0)
        .update_with(contract_address)
        .update_with(selector)
        .update_with(calldata_hash)
        .update_with(MAX_FEE)
        .update_with(CHAIN_ID)
        .update_with(7)
        .finalize()
}

fn assert_external_calls_to(contract_address: ContractAddress, expected_calls: Array<CallInfo>) {
    let dispatcher = IObserverDispatcher { contract_address };
    let external_calls = dispatcher.get_all_calls();
    assert_eq!(external_calls, expected_calls);
}

fn print_external_calls_to(contract_address: ContractAddress, tag: felt252) {
    let dispatcher = IObserverDispatcher { contract_address };
    let calls = dispatcher.get_all_calls();
    println!("--------------------------------");
    println!("Total of {:?} external calls to {:?}:", calls.len(), tag);
    for call in calls {
        println!("{:?}", call);
    }
}

#[generate_trait]
impl SpyHelpersImpl of SpyHelpers {
    fn assert_event_external_call(
        ref self: EventSpy,
        contract: ContractAddress,
        caller: ContractAddress,
        tx_version: felt252,
        chain_id: felt252,
        tx_hash: felt252,
    ) {
        let expected = ObserverComponent::Event::ExternalCall(
            CallInfo { caller, tx_version, chain_id, tx_hash },
        );
        self.assert_emitted_single(contract, expected);
    }
}
