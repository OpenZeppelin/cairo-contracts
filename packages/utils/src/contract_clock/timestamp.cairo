use openzeppelin_utils::contract_clock::interface::IERC6372;

pub impl ERC6372TimestampClock of IERC6372 {
    fn clock() -> u64 {
        starknet::get_block_timestamp()
    }

    fn CLOCK_MODE() -> ByteArray {
        "mode=timestamp&from=starknet::SN_MAIN"
    }
}
