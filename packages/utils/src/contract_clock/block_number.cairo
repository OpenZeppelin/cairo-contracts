use openzeppelin_utils::contract_clock::interface::IERC6372;

pub impl ERC6372BlockNumberClock of IERC6372 {
    fn clock() -> u64 {
        starknet::get_block_number()
    }

    fn CLOCK_MODE() -> ByteArray {
        "mode=blocknumber&from=default"
    }
}