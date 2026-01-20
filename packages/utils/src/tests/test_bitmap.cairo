use core::num::traits::Bounded;
use openzeppelin_test_common::mocks::bitmap::{IMockBitMap, MockBitMap};

fn CONTRACT_STATE() -> MockBitMap::ContractState {
    MockBitMap::contract_state_for_testing()
}

#[test]
fn test_get_defaults_to_false() {
    let state = CONTRACT_STATE();

    // Unset bitmap entries should read as false across multiple buckets.
    assert_eq!(state.get(0), false);
    assert_eq!(state.get(1), false);
    assert_eq!(state.get(127), false);
    assert_eq!(state.get(128), false);
}

#[test]
fn test_set_and_get_first_bucket_bits() {
    let mut state = CONTRACT_STATE();

    // Bits 0..127 live in the first bucket.
    state.set(0);
    state.set(1);
    state.set(127);

    assert_eq!(state.get(0), true);
    assert_eq!(state.get(1), true);
    assert_eq!(state.get(127), true);

    // A nearby bit that was not set should remain false.
    assert_eq!(state.get(2), false);
}

#[test]
fn test_set_and_get_second_bucket_bits() {
    let mut state = CONTRACT_STATE();

    // Bits 128..255 live in the second bucket.
    state.set(128);
    state.set(255);

    assert_eq!(state.get(128), true);
    assert_eq!(state.get(255), true);

    // Setting second-bucket bits should not affect first-bucket bits.
    assert_eq!(state.get(127), false);
}

#[test]
fn test_bucket_boundaries_are_independent() {
    let mut state = CONTRACT_STATE();

    // 127 is the last bit of bucket 0, 128 is the first bit of bucket 1.
    state.set(127);
    assert_eq!(state.get(127), true);
    assert_eq!(state.get(128), false);

    state.set(128);
    assert_eq!(state.get(127), true);
    assert_eq!(state.get(128), true);
}

#[test]
fn test_unset_clears_only_target_bit() {
    let mut state = CONTRACT_STATE();

    // Unsetting should only clear the specified bit, not its neighbors.
    state.set(5);
    state.set(6);
    state.unset(5);

    assert_eq!(state.get(5), false);
    assert_eq!(state.get(6), true);
}

#[test]
fn test_set_to_toggles_value() {
    let mut state = CONTRACT_STATE();

    // set_to(true) should set, set_to(false) should clear the same bit.
    state.set_to(42, true);
    assert_eq!(state.get(42), true);

    state.set_to(42, false);
    assert_eq!(state.get(42), false);
}

#[test]
fn test_set_is_idempotent() {
    let mut state = CONTRACT_STATE();

    // Setting a bit multiple times should have the same effect as setting it once.
    state.set(100);
    assert_eq!(state.get(100), true);

    state.set(100);
    assert_eq!(state.get(100), true);
}

#[test]
fn test_unset_is_idempotent() {
    let mut state = CONTRACT_STATE();

    // Unsetting a bit that was never set should be safe.
    state.unset(200);
    assert_eq!(state.get(200), false);

    // Unsetting an already unset bit should remain false.
    state.unset(200);
    assert_eq!(state.get(200), false);
}

#[test]
fn test_bucket_boundary_neighbors() {
    let mut state = CONTRACT_STATE();

    // Test the boundary between bucket 0 (bit 127) and bucket 1 (bit 128).
    state.set(127);
    state.set(128);

    assert_eq!(state.get(127), true);
    assert_eq!(state.get(128), true);
    assert_eq!(state.get(126), false);
    assert_eq!(state.get(129), false);
}

#[test]
fn test_multiple_bits_same_bucket() {
    let mut state = CONTRACT_STATE();

    // Set multiple bits in the same bucket at various positions.
    state.set(0);
    state.set(32);
    state.set(64);
    state.set(96);
    state.set(127);

    // All should be set.
    assert_eq!(state.get(0), true);
    assert_eq!(state.get(32), true);
    assert_eq!(state.get(64), true);
    assert_eq!(state.get(96), true);
    assert_eq!(state.get(127), true);

    // Unset one in the middle, others should remain.
    state.unset(64);
    assert_eq!(state.get(0), true);
    assert_eq!(state.get(32), true);
    assert_eq!(state.get(64), false);
    assert_eq!(state.get(96), true);
    assert_eq!(state.get(127), true);
}

#[test]
fn test_large_indices() {
    let mut state = CONTRACT_STATE();

    // Test with very large indices close to u256::MAX to ensure bucket calculation works correctly.
    // Use values that are close to the maximum but still allow for bit positions 0-127 within the
    // bucket.
    let max_u256: u256 = Bounded::MAX;
    let bucket_size: u256 = 128;
    let very_large_bucket = max_u256 / bucket_size;

    // Test indices in the last possible bucket (or close to it)
    let large_index_1 = very_large_bucket * bucket_size;
    let large_index_2 = very_large_bucket * bucket_size + 64;
    let large_index_3 = very_large_bucket * bucket_size + 127;

    state.set(large_index_1);
    state.set(large_index_2);
    state.set(large_index_3);

    assert_eq!(state.get(large_index_1), true);
    assert_eq!(state.get(large_index_2), true);
    assert_eq!(state.get(large_index_3), true);

    // Adjacent bit at the previous bucket boundary should be independent.
    assert_eq!(state.get(large_index_1 - 1), false);

    // Also test with another very large value (close to max but in a different bucket)
    let near_max_index = max_u256 - 1000;
    state.set(near_max_index);
    assert_eq!(state.get(near_max_index), true);
    assert_eq!(state.get(near_max_index - 1), false);
    assert_eq!(state.get(near_max_index + 1), false);
}

#[test]
fn test_sequence_of_operations() {
    let mut state = CONTRACT_STATE();

    // Test a sequence of set/unset operations on the same bit.
    let index = 50;

    state.set(index);
    assert_eq!(state.get(index), true);

    state.unset(index);
    assert_eq!(state.get(index), false);

    state.set(index);
    assert_eq!(state.get(index), true);

    state.set_to(index, false);
    assert_eq!(state.get(index), false);

    state.set_to(index, true);
    assert_eq!(state.get(index), true);
}
