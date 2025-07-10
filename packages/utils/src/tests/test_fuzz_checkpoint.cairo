use openzeppelin_test_common::mocks::checkpoint::{IMockTrace, MockTrace};
use starknet::storage_access::StorePacking;
use crate::structs::Checkpoint;

fn CONTRACT_STATE() -> MockTrace::ContractState {
    MockTrace::contract_state_for_testing()
}

#[test]
#[fuzzer]
fn test_push_multiple(checkpoints: Span<Checkpoint>) {
    let mut mock_trace = CONTRACT_STATE();

    let mut expected_prev = 0;
    for point in checkpoints {
        let (prev, new) = mock_trace.push_checkpoint(*point.key, *point.value);
        assert_eq!(prev, expected_prev);
        assert_eq!(new, *point.value);
        expected_prev = new;
    }
    assert_eq!(mock_trace.get_length(), checkpoints.len().into());
}

#[test]
#[fuzzer]
fn test_upper_lookup(checkpoints: Span<Checkpoint>) {
    let mut mock_trace = CONTRACT_STATE();
    push_checkpoints(checkpoints);

    for point in checkpoints {
        let found_value = mock_trace.upper_lookup(*point.key);
        assert_eq!(found_value, *point.value);
    }
}

#[test]
#[fuzzer]
fn test_upper_lookup_recent(checkpoints: Span<Checkpoint>) {
    let mut mock_trace = CONTRACT_STATE();
    push_checkpoints(checkpoints);

    for point in checkpoints {
        let found_value = mock_trace.upper_lookup_recent(*point.key);
        assert_eq!(found_value, *point.value);
    }
}

#[test]
#[fuzzer]
fn test_get_at_position(checkpoints: Span<Checkpoint>) {
    let mut mock_trace = CONTRACT_STATE();
    push_checkpoints(checkpoints);

    for i in 0..checkpoints.len() {
        let index = i.try_into().unwrap();
        let checkpoint = *checkpoints.at(index);
        let found_checkpoint = mock_trace.get_at_position(i.into());
        assert!(found_checkpoint == checkpoint);
    }
}

#[test]
#[fuzzer]
#[should_panic(expected: 'Vec overflow')]
fn test_at_position_out_of_bounds(checkpoints: Span<Checkpoint>) {
    let mut mock_trace = CONTRACT_STATE();
    push_checkpoints(checkpoints);

    mock_trace.get_at_position(checkpoints.len().into());
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

use snforge_std::cheatcodes::generate_arg::generate_arg;
use snforge_std::fuzzable::Fuzzable;

const MIN_LEN: u64 = 2;
const MAX_LEN: u64 = 100;
const MIN_KEY_STEP: u64 = 1;
const MAX_KEY_STEP: u64 = 1_000_000;

impl CheckpointsFuzzable of Fuzzable<Span<Checkpoint>> {
    fn blank() -> Span<Checkpoint> {
        array![].span()
    }

    fn generate() -> Span<Checkpoint> {
        let len = generate_arg(MIN_LEN, MAX_LEN);
        let key_step = generate_arg(MIN_KEY_STEP, MAX_KEY_STEP);
        let mut checkpoints = array![];
        for i in 0..len {
            // Keys are guaranteed to be positive and increase by `key_step`
            let key = 1 + key_step * i;
            // Values are guaranteed to be positive, different and increase by 1
            let value = (1 + i).into();
            checkpoints.append(Checkpoint { key, value });
        }
        checkpoints.span()
    }
}

fn push_checkpoints(checkpoints: Span<Checkpoint>) {
    let mut mock_trace = CONTRACT_STATE();
    for point in checkpoints {
        mock_trace.push_checkpoint(*point.key, *point.value);
    }
}
