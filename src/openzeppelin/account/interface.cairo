use array::ArrayTrait;
use array::SpanTrait;
use starknet::ContractAddress;

const IBASEACCOUNT_ID: felt252 = 0x1b1ea4b3558403d2642eced0b726fff3e36bc8677929ddbe33ae4141d2e12f9;
const IDECLARER_ID: felt252 = 0x93387b6ff0b5183657eb3eaf9ed6f5743d76e2ed8b8f64c3d7b54426dfcf8;
const IERC1271_ID: felt252 = 0x37f26a44ac1097d95d4c6816c92d5b0f30163fb64868a1de7c3fa17d7c2d334;

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
