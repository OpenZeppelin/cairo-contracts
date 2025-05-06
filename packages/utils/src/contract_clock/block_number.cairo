use openzeppelin_utils::contract_clock::IERC6372Clock;

pub impl ERC6372BlockNumberClock of IERC6372Clock {
    fn clock() -> u64 {
        starknet::get_block_number()
    }

    fn CLOCK_MODE() -> ByteArray {
        "mode=blocknumber&from=default"
    }
}
