use array::ArrayTrait;
use array::SpanTrait;
use starknet::ContractAddress;

const IBASEACCOUNT_ID: felt252 = 0x161ab6ad32c5db670d95c8d430a19024784b4f88b39e4cf2f2cb9b1917fbcd5;
const IDECLARER_ID: felt252 = 0x34631381ed51f6ce7cabca2a62dc0baaf5b7ec0839e6784bbcde343287ca370;
const IERC1271_ID: felt252 = 0xb1cb0d9c7e56541e00127a4bf99f4d57a37ebcdd079253dc2f172f71af0d9;

#[derive(Serde, Drop)]
struct Call {
    to: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>
}

trait IBaseAccount {
    fn __execute__(calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(calls: Array<Call>) -> felt252;
}

trait IDeclarer {
    fn __validate_declare__(class_hash: felt252) -> felt252;
}

trait IERC1271 {
    fn is_valid_signature(message: felt252, signature: Array<felt252>) -> felt252;
}
