use openzeppelin_utils::contract_clock::ERC6372Clock;

pub impl ERC6372BlockNumberClock of ERC6372Clock {
    /// See `ERC6372Clock::clock`.
    fn clock() -> u64 {
        starknet::get_block_number()
    }

    /// See `ERC6372Clock::CLOCK_MODE`.
    fn CLOCK_MODE() -> ByteArray {
        "mode=blocknumber&from=starknet::SN_MAIN"
    }
}
