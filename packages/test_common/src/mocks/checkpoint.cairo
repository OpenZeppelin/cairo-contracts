use openzeppelin_utils::structs::Checkpoint;

#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn push_checkpoint(ref self: TContractState, key: u64, value: u256) -> (u256, u256);
    fn get_latest(self: @TContractState) -> u256;
    fn get_at_position(self: @TContractState, pos: u64) -> Checkpoint;
    fn upper_lookup(self: @TContractState, key: u64) -> u256;
    fn upper_lookup_recent(self: @TContractState, key: u64) -> u256;
    fn get_length(self: @TContractState) -> u64;
}

#[starknet::contract]
pub mod MockTrace {
    use openzeppelin_utils::structs::checkpoint::{Checkpoint, Trace, TraceTrait};

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

        fn get_at_position(self: @ContractState, pos: u64) -> Checkpoint {
            self.trace.deref().at(pos)
        }

        fn upper_lookup(self: @ContractState, key: u64) -> u256 {
            self.trace.deref().upper_lookup(key)
        }

        fn upper_lookup_recent(self: @ContractState, key: u64) -> u256 {
            self.trace.deref().upper_lookup_recent(key)
        }

        fn get_length(self: @ContractState) -> u64 {
            self.trace.deref().length()
        }
    }
}
