use crate::structs::Checkpoint;
use openzeppelin_test_common::mocks::checkpoint::{IMockTrace, MockTrace};
use starknet::storage_access::StorePacking;

fn CONTRACT_STATE() -> MockTrace::ContractState {
    MockTrace::contract_state_for_testing()
}

#[test]
#[fuzzer]
fn test_push_multiple(len_seed: u64, key_step_seed: u64) {
    let len = 2 + len_seed % 99; // [2..100]
    let key_step = 1 + key_step_seed % 1_000_000; // [1..1_000_000]

    let mut mock_trace = CONTRACT_STATE();
    let checkpoints = build_checkpoints_array(len, key_step);

    let mut expected_prev = 0;
    for point in checkpoints {
        let (prev, new) = mock_trace.push_checkpoint(*point.key, *point.value);
        assert_eq!(prev, expected_prev);
        assert_eq!(new, *point.value);
        expected_prev = new;
    };
    assert_eq!(mock_trace.get_length(), len);
}

#[test]
#[fuzzer]
fn test_upper_lookup(len_seed: u64, key_step_seed: u64) {
    let len = 2 + len_seed % 99; // [2..100]
    let key_step = 1 + key_step_seed % 1_000_000; // [1..1_000_000]

    let mut mock_trace = CONTRACT_STATE();
    let checkpoints = build_checkpoints_array(len, key_step);
    push_checkpoints(checkpoints);

    for i in 0..len {
        let index = i.try_into().unwrap();
        let checkpoint = *checkpoints.at(index);
        let found_value = mock_trace.upper_lookup(checkpoint.key);
        assert_eq!(found_value, checkpoint.value);
    };
}

#[test]
#[fuzzer]
fn test_upper_lookup_recent(len_seed: u64, key_step_seed: u64) {
    let len = 2 + len_seed % 99; // [2..100]
    let key_step = 1 + key_step_seed % 1_000_000; // [1..1_000_000]

    let mut mock_trace = CONTRACT_STATE();
    let checkpoints = build_checkpoints_array(len, key_step);
    push_checkpoints(checkpoints);

    for i in 0..len {
        let index = i.try_into().unwrap();
        let checkpoint = *checkpoints.at(index);
        let found_value = mock_trace.upper_lookup_recent(checkpoint.key);
        assert_eq!(found_value, checkpoint.value);
    };
}

#[test]
#[fuzzer]
fn test_get_at_position(len_seed: u64, key_step_seed: u64) {
    let len = 2 + len_seed % 99; // [2..100]
    let key_step = 1 + key_step_seed % 1_000_000; // [1..1_000_000]

    let mut mock_trace = CONTRACT_STATE();
    let checkpoints = build_checkpoints_array(len, key_step);
    push_checkpoints(checkpoints);

    for i in 0..len {
        let index = i.try_into().unwrap();
        let checkpoint = *checkpoints.at(index);
        let found_checkpoint = mock_trace.get_at_position(i);
        assert!(found_checkpoint == checkpoint);
    };
}

#[test]
#[fuzzer]
#[should_panic(expected: 'Vec overflow')]
fn test_at_position_out_of_bounds(len_seed: u64, key_step_seed: u64) {
    let len = 2 + len_seed % 99; // [2..100]
    let key_step = 1 + key_step_seed % 1_000_000; // [1..1_000_000]

    let mut mock_trace = CONTRACT_STATE();
    let checkpoints = build_checkpoints_array(len, key_step);
    push_checkpoints(checkpoints);

    mock_trace.get_at_position(len);
}

#[test]
#[fuzzer]
fn test_pack_unpack(key: u64, value: u256) {
    let initial_checkpoint = Checkpoint { key, value };

    let packed_value = StorePacking::pack(initial_checkpoint);
    let unpacked_checkpoint: Checkpoint = StorePacking::unpack(packed_value);

    assert!(initial_checkpoint == unpacked_checkpoint);
}

//
// Helpers
//

fn build_checkpoints_array(len: u64, key_step: u64) -> Span<Checkpoint> {
    let mut checkpoints = array![];
    for i in 0..len {
        // Keys are guaranteed to be positive and increase by `key_step`
        let key = 1 + key_step * i;
        // Values are guaranteed to be positive, different and increase by 1
        let value = (1 + i).into();
        checkpoints.append(Checkpoint { key, value });
    };
    checkpoints.span()
}

fn push_checkpoints(checkpoints: Span<Checkpoint>) {
    let mut mock_trace = CONTRACT_STATE();
    for point in checkpoints {
        mock_trace.push_checkpoint(*point.key, *point.value);
    };
}
