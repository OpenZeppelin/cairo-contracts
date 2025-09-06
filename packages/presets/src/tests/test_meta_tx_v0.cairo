use core::hash::{HashStateExTrait, HashStateTrait};
use core::pedersen::PedersenTrait;
use openzeppelin_test_common::mocks::account::ILegacyAccountDispatcher;
use openzeppelin_test_common::mocks::counter::{ICounterDispatcher, ICounterDispatcherTrait};
use openzeppelin_test_common::mocks::observer::{
    CallInfo, IObserverDispatcher, IObserverDispatcherTrait,
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::ZERO;
use openzeppelin_testing::constants::stark::KEY_PAIR;
use openzeppelin_testing::signing::StarkSerializedSigning;
use openzeppelin_testing::{
    AsAddressTrait, EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent, spy_events,
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
const CHAIN_ID: felt252 = 'SN_SEPOLIA';

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
    let tx_hash = compute_invoke_v0_tx_hash(ACCOUNT, EXECUTE_SELECTOR, calldata.span());
    let signature = KEY_PAIR().serialized_sign(tx_hash).span();

    // Setup dispatchers
    let (meta_tx_dispatcher, account_dispatcher, counter_dispatcher) = setup_dispatchers(
        tx_hash, CHAIN_ID,
    );

    // Check initial state of counter
    let counter = counter_dispatcher.get_current_value();
    assert_eq!(counter, 0);

    // Execute meta tx
    let mut spy = spy_events();
    meta_tx_dispatcher
        .execute_meta_tx_v0(
            account_dispatcher.contract_address, EXECUTE_SELECTOR, calldata.span(), signature,
        )
        .unwrap_syscall();

    // Check registered calls
    assert_external_calls_to(
        ACCOUNT,
        array![CallInfo { caller: ZERO, tx_version: TX_VERSION_0, chain_id: CHAIN_ID, tx_hash }],
    );
    assert_external_calls_to(
        COUNTER,
        array![
            CallInfo { caller: ACCOUNT, tx_version: TX_VERSION_0, chain_id: CHAIN_ID, tx_hash },
            CallInfo { caller: ACCOUNT, tx_version: TX_VERSION_0, chain_id: CHAIN_ID, tx_hash },
            CallInfo { caller: ACCOUNT, tx_version: TX_VERSION_0, chain_id: CHAIN_ID, tx_hash },
        ],
    );

    // Check events
    spy.assert_event_external_call(COUNTER, ACCOUNT, TX_VERSION_0, CHAIN_ID, tx_hash);
    spy.assert_event_external_call(COUNTER, ACCOUNT, TX_VERSION_0, CHAIN_ID, tx_hash);
    spy.assert_event_external_call(COUNTER, ACCOUNT, TX_VERSION_0, CHAIN_ID, tx_hash);
    spy.assert_event_external_call(ACCOUNT, ZERO, TX_VERSION_0, CHAIN_ID, tx_hash);

    spy.assert_no_events_left_from(COUNTER);

    // Check final state of counter
    let expected_counter = incr_1 + incr_2 + incr_3;
    let counter = counter_dispatcher.get_current_value();
    assert_eq!(counter, expected_counter);
}

//
// Helpers
//

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
        let expected = ExpectedEvent::new()
            .key(selector!("ExternalCall"))
            .data(caller)
            .data(tx_version)
            .data(chain_id)
            .data(tx_hash);
        self.assert_emitted_single(contract, expected);
    }
}
