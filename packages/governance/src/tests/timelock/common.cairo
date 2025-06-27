use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy};
use starknet::ContractAddress;
use starknet::account::Call;
use crate::timelock::TimelockControllerComponent::{
    CallCancelled, CallExecuted, CallSalt, CallScheduled, MinDelayChanged,
};
use crate::timelock::interface::{TimelockABIDispatcher, TimelockABIDispatcherTrait};
use crate::timelock::{OperationState, TimelockControllerComponent};

#[generate_trait]
pub(crate) impl TimelockSpyHelpersImpl of TimelockSpyHelpers {
    //
    // CallScheduled
    //

    fn assert_event_call_scheduled(
        ref self: EventSpy,
        contract: ContractAddress,
        id: felt252,
        index: felt252,
        call: Call,
        predecessor: felt252,
        delay: u64,
    ) {
        let expected = TimelockControllerComponent::Event::CallScheduled(
            CallScheduled { id, index, call, predecessor, delay },
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_call_scheduled(
        ref self: EventSpy,
        contract: ContractAddress,
        id: felt252,
        index: felt252,
        call: Call,
        predecessor: felt252,
        delay: u64,
    ) {
        self.assert_event_call_scheduled(contract, id, index, call, predecessor, delay);
        self.assert_no_events_left_from(contract);
    }

    fn assert_events_call_scheduled_batch(
        ref self: EventSpy,
        contract: ContractAddress,
        id: felt252,
        calls: Span<Call>,
        predecessor: felt252,
        delay: u64,
    ) {
        let mut i = 0;
        while i != calls.len() {
            self
                .assert_event_call_scheduled(
                    contract, id, i.into(), *calls.at(i), predecessor, delay,
                );
            i += 1;
        };
    }

    fn assert_only_events_call_scheduled_batch(
        ref self: EventSpy,
        contract: ContractAddress,
        id: felt252,
        calls: Span<Call>,
        predecessor: felt252,
        delay: u64,
    ) {
        self.assert_events_call_scheduled_batch(contract, id, calls, predecessor, delay);
        self.assert_no_events_left_from(contract);
    }

    //
    // CallSalt
    //

    fn assert_event_call_salt(
        ref self: EventSpy, contract: ContractAddress, id: felt252, salt: felt252,
    ) {
        let expected = TimelockControllerComponent::Event::CallSalt(CallSalt { id, salt });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_call_salt(
        ref self: EventSpy, contract: ContractAddress, id: felt252, salt: felt252,
    ) {
        self.assert_event_call_salt(contract, id, salt);
        self.assert_no_events_left_from(contract);
    }

    //
    // Cancelled
    //

    fn assert_event_call_cancelled(ref self: EventSpy, contract: ContractAddress, id: felt252) {
        let expected = TimelockControllerComponent::Event::CallCancelled(CallCancelled { id });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_call_cancelled(
        ref self: EventSpy, contract: ContractAddress, id: felt252,
    ) {
        self.assert_event_call_cancelled(contract, id);
        self.assert_no_events_left_from(contract);
    }

    //
    // CallExecuted
    //

    fn assert_event_call_executed(
        ref self: EventSpy, contract: ContractAddress, id: felt252, index: felt252, call: Call,
    ) {
        let expected = TimelockControllerComponent::Event::CallExecuted(
            CallExecuted { id, index, call },
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_call_executed(
        ref self: EventSpy, contract: ContractAddress, id: felt252, index: felt252, call: Call,
    ) {
        self.assert_event_call_executed(contract, id, index, call);
        self.assert_no_events_left_from(contract);
    }

    fn assert_events_call_executed_batch(
        ref self: EventSpy, contract: ContractAddress, id: felt252, calls: Span<Call>,
    ) {
        let mut i = 0;
        while i != calls.len() {
            self.assert_event_call_executed(contract, id, i.into(), *calls.at(i));
            i += 1;
        };
    }

    fn assert_only_events_call_executed_batch(
        ref self: EventSpy, contract: ContractAddress, id: felt252, calls: Span<Call>,
    ) {
        self.assert_events_call_executed_batch(contract, id, calls);
        self.assert_no_events_left_from(contract);
    }

    //
    // MinDelayChanged
    //

    fn assert_event_delay_changed(
        ref self: EventSpy, contract: ContractAddress, old_duration: u64, new_duration: u64,
    ) {
        let expected = TimelockControllerComponent::Event::MinDelayChanged(
            MinDelayChanged { old_duration, new_duration },
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_delay_changed(
        ref self: EventSpy, contract: ContractAddress, old_duration: u64, new_duration: u64,
    ) {
        self.assert_event_delay_changed(contract, old_duration, new_duration);
        self.assert_no_events_left_from(contract);
    }
}

//
// Assertions
//

pub(crate) fn assert_operation_state(
    timelock: TimelockABIDispatcher, exp_state: OperationState, id: felt252,
) {
    let operation_state = timelock.get_operation_state(id);
    assert_eq!(operation_state, exp_state);

    let is_operation = timelock.is_operation(id);
    let is_pending = timelock.is_operation_pending(id);
    let is_ready = timelock.is_operation_ready(id);
    let is_done = timelock.is_operation_done(id);

    match exp_state {
        OperationState::Unset => {
            assert!(!is_operation);
            assert!(!is_pending);
            assert!(!is_ready);
            assert!(!is_done);
        },
        OperationState::Waiting => {
            assert!(is_operation);
            assert!(is_pending);
            assert!(!is_ready);
            assert!(!is_done);
        },
        OperationState::Ready => {
            assert!(is_operation);
            assert!(is_pending);
            assert!(is_ready);
            assert!(!is_done);
        },
        OperationState::Done => {
            assert!(is_operation);
            assert!(!is_pending);
            assert!(!is_ready);
            assert!(is_done);
        },
    };
}
