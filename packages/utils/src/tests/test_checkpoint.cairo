use core::num::traits::Bounded;
use crate::structs::checkpoint::Checkpoint;
use crate::structs::checkpoint::CheckpointStorePacking;

const _2_POW_184: felt252 = 0x10000000000000000000000000000000000000000000000;
const KEY_MASK: u256 = 0xffffffffffffffff;
const LOW_MASK: u256 = 0xffffffffffffffffffffffffffffffff;

#[test]
fn test_pack_big_key_and_value() {
    let key = Bounded::MAX;
    let value = Bounded::MAX;
    let checkpoint = Checkpoint { key, value };

    let (key_and_low, high) = CheckpointStorePacking::pack(checkpoint);

    let expected_key: u256 = (key_and_low.into() / _2_POW_184.into()) & KEY_MASK;
    let expected_low: u256 = key_and_low.into() & LOW_MASK;
    let expected_high: felt252 = Bounded::<u128>::MAX.into();

    assert_eq!(key.into(), expected_key);
    assert_eq!(value.low.into(), expected_low);
    assert_eq!(high, expected_high);
}

#[test]
fn test_unpack_big_key_and_value() {
    let key_and_low = Bounded::<u64>::MAX.into() * _2_POW_184 + Bounded::<u128>::MAX.into();
    let high = Bounded::<u128>::MAX.into();

    let checkpoint = CheckpointStorePacking::unpack((key_and_low, high));

    let expected_key: u64 = Bounded::MAX;
    let expected_value: u256 = Bounded::MAX;

    assert_eq!(checkpoint.key, expected_key);
    assert_eq!(checkpoint.value, expected_value);
}
