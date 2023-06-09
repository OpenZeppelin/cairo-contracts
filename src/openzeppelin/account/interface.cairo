use array::ArrayTrait;
use array::SpanTrait;
use starknet::ContractAddress;

const IACCOUNT_ID: felt252 = 0x39d1c9eab76ed04e063bc5419887a56af4c816e39588d7910fc973ff71315c5;
const IERC1271_ID: felt252 = 0xb1cb0d9c7e56541e00127a4bf99f4d57a37ebcdd079253dc2f172f71af0d9;

#[derive(Serde, Drop)]
struct Call {
    to: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>
}

trait IAccount {
    fn __execute__(calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(calls: Array<Call>) -> felt252;
    fn __validate_declare__(class_hash: felt252) -> felt252;
    fn supports_interface(interface_id: felt252) -> bool;
}

trait IERC1271 {
    fn is_valid_signature(message: felt252, signature: Array<felt252>) -> felt252;
}
