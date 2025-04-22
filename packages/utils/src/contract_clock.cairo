#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub enum ClockReference {
    BlockNumber,
    Timestamp,
}

#[starknet::interface]
pub trait IERC6372<TState> {
    /// Returns the current clock value used for time-dependent operations.
    fn clock(self: @TState) -> u64;

    /// Returns a parsable description of the clock's mode or time measurement mechanism.
    fn CLOCK_MODE(self: @TState) -> ByteArray;

    /// Returns the clock reference indicating whether the clock is based on block number or
    /// timestamp.
    fn CLOCK_REFERENCE(self: @TState) -> ClockReference;
}

pub impl ERC6372BlockNumberClock<TState, +Drop<TState>> of IERC6372<TState> {
    fn clock(self: @TState) -> u64 {
        starknet::get_block_number()
    }

    fn CLOCK_MODE(self: @TState) -> ByteArray {
        "mode=blocknumber&from=default"
    }

    fn CLOCK_REFERENCE(self: @TState) -> ClockReference {
        ClockReference::BlockNumber
    }
}

pub impl ERC6372TimestampClock<TState, +Drop<TState>> of IERC6372<TState> {
    fn clock(self: @TState) -> u64 {
        starknet::get_block_timestamp()
    }

    fn CLOCK_MODE(self: @TState) -> ByteArray {
        "mode=timestamp&from=starknet::SN_MAIN"
    }

    fn CLOCK_REFERENCE(self: @TState) -> ClockReference {
        ClockReference::Timestamp
    }
}
