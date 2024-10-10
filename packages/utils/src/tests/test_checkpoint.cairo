

#[starknet::interface]
trait IMockTrace<TContractState> {
    fn push_checkpoint(ref self: TContractState, key: u64, value: u256) -> (u256, u256);
    fn get_latest(self: @TContractState) -> u256;
    fn get_at_key(self: @TContractState, key: u64) -> u256;
    fn get_length(self: @TContractState) -> u64;
}

#[starknet::contract]
pub mod MockTrace {
    use openzeppelin_utils::structs::checkpoint::{Trace, TraceTrait};

    #[storage]
    struct Storage {
        trace: Trace,
    }

    #[abi(embed_v0)]
    impl MockTraceImpl of super::IMockTrace<ContractState> {
        fn push_checkpoint(ref self: ContractState, key: u64, value: u256) -> (u256, u256) {   
            self.trace.deref().push(key, value)
        }

        fn get_latest(self: @ContractState) -> u256 {
            self.trace.deref().latest()
        }

        fn get_at_key(self: @ContractState, key: u64) -> u256 {
            self.trace.deref().upper_lookup(key)
        }

        fn get_length(self: @ContractState) -> u64 {
            self.trace.deref().length()
        }
    }
}

mod tests {
    use core::num::traits::Bounded;
    use crate::structs::checkpoint::Checkpoint;
    use crate::structs::checkpoint::CheckpointStorePacking;
    use super::IMockTrace;

    const _2_POW_184: felt252 = 0x10000000000000000000000000000000000000000000000;
    const KEY_MASK: u256 = 0xffffffffffffffff;
    const LOW_MASK: u256 = 0xffffffffffffffffffffffffffffffff;

    fn CONTRACT_STATE() -> super::MockTrace::ContractState {
        super::MockTrace::contract_state_for_testing()
    }

    #[test]
    fn test_push_checkpoint() {
        let mut mock_trace = CONTRACT_STATE();

        let (prev, new) = mock_trace.push_checkpoint(100, 1000);
        assert(prev == 0, 'Incorrect previous value');
        assert(new == 1000, 'Incorrect new value');

        let (prev, new) = mock_trace.push_checkpoint(200, 2000);
        assert(prev == 1000, 'Incorrect previous value');
        assert(new == 2000, 'Incorrect new value');
    }

    #[test]
    fn test_get_latest() {
        let mut mock_trace = CONTRACT_STATE();

        mock_trace.push_checkpoint(100, 1000);
        mock_trace.push_checkpoint(200, 2000);

        let latest = mock_trace.get_latest();
        assert(latest == 2000, 'Incorrect latest value');
    }

    #[test]
    fn test_get_at_key() {
        let mut mock_trace = CONTRACT_STATE();

        mock_trace.push_checkpoint(100, 1000);
        mock_trace.push_checkpoint(200, 2000);
        mock_trace.push_checkpoint(300, 3000);

        let value_at_150 = mock_trace.get_at_key(150);
        assert(value_at_150 == 1000, 'Incorrect value at key 150');

        let value_at_250 = mock_trace.get_at_key(250);
        assert(value_at_250 == 2000, 'Incorrect value at key 250');

        let value_at_350 = mock_trace.get_at_key(350);
        assert(value_at_350 == 3000, 'Incorrect value at key 350');
    }

    #[test]
    fn test_get_length() {
        let mut mock_trace = CONTRACT_STATE();

        assert(mock_trace.get_length() == 0, 'Initial length should be 0');

        mock_trace.push_checkpoint(100, 1000);
        assert(mock_trace.get_length() == 1, 'Length should be 1');

        mock_trace.push_checkpoint(200, 2000);
        assert(mock_trace.get_length() == 2, 'Length should be 2');
    }

    #[test]
    #[should_panic(expected: ('Unordered insertion',))]
    fn test_unordered_insertion() {
        let mut mock_trace = CONTRACT_STATE();

        mock_trace.push_checkpoint(200, 2000);
        mock_trace.push_checkpoint(100, 1000); // This should panic
    }

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
}
