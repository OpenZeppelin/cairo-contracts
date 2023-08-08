/// This is a base "abstract" contract that tracks voting units, which are a measure of voting power that can be
/// transferred, and provides a system of vote delegation, where an account can delegate its voting units to a sort of
/// "representative" that will pool delegated voting units from different accounts and can then use it to vote in
/// decisions. In fact, voting units MUST be delegated in order to count as actual votes, and an account has to
/// delegate those votes to itself if it wishes to participate in decisions and does not have a trusted representative.
#[starknet::contract]
mod Votes {
    use openzeppelin::governance::utils::interfaces::IVotes;
    use openzeppelin::utils::structs::checkpoints::{Trace, TraceTrait};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        _delegation: LegacyMap<ContractAddress, ContractAddress>,
        _delegateCheckpoints: LegacyMap<ContractAddress, Trace>,
        _totalCheckpoints: Trace
    }

    mod Errors {
        const INCONSISTENT_CLOCK: felt252 = 'Inconsistent Clock';
    }

    /// Clock used for flagging checkpoints. Can be overridden to implement block number based
    /// checkpoints (and voting), in which case {CLOCK_MODE} should be overridden as well to match.
    fn clock() -> u64 {
        starknet::get_block_timestamp()
    }

    /// Machine-readable description of the clock as specified in EIP-6372.
    fn CLOCK_MODE() -> felt252 {
        // Check that the clock was not modified
        assert(clock() == starknet::get_block_timestamp(), Errors::INCONSISTENT_CLOCK);

        'mode=timestamp'
    }

    #[external(v0)]
    impl VotesImpl of IVotes<ContractState> {
        /// Returns the current amount of votes that `account` has.
        fn getVotes(self: @ContractState, account: ContractAddress) -> u256 {
            self._delegateCheckpoints.read(account).latest()
        }
    }
}
