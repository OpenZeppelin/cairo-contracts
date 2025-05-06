use openzeppelin_utils::contract_clock::IERC6372Clock;

pub impl ERC6372TimestampClock of IERC6372Clock {
    fn clock() -> u64 {
        starknet::get_block_timestamp()
    }

    fn CLOCK_MODE() -> ByteArray {
        "mode=timestamp&from=starknet::SN_MAIN"
    }
}
