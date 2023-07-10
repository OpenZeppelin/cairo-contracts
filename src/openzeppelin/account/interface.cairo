use array::ArrayTrait;
use array::SpanTrait;
use starknet::ContractAddress;

const ISRC6_ID: felt252 = 0x2ceccef7f994940b3962a6c67e0ba4fcd37df7d131417c604f91e03caecc1cd;

#[derive(Serde, Drop)]
struct Call {
    to: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>
}

trait ISRC6 {
    fn __execute__(calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(calls: Array<Call>) -> felt252;
    fn is_valid_signature(message: felt252, signature: Array<felt252>) -> felt252;
}

trait IDeclarer {
    fn __validate_declare__(class_hash: felt252) -> felt252;
}
