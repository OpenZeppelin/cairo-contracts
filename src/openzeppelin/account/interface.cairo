use array::ArrayTrait;
use array::SpanTrait;
use starknet::ContractAddress;

const IACCOUNT_ID: felt252 = 0x36c738c1c375b993078fe6b517d477e5a3c9b104e40c04662c4bdd3e2f5fa4a;
const ERC1271_VALIDATED: u32 = 0x1626ba7e_u32;

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
    fn is_valid_signature(message: felt252, signature: Array<felt252>) -> u32;
    fn supports_interface(interface_id: felt252) -> bool;
}
