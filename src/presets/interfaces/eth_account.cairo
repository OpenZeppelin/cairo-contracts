use openzeppelin::account::interface::EthPublicKey;
use openzeppelin::account::utils::secp256k1::Secp256k1PointSerde;
use starknet::account::Call;
use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait EthAccountUpgradeableABI<TState> {
    // ISRC6
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IEthDeployable
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, public_key: EthPublicKey
    ) -> felt252;

    // IEthPublicKey
    fn get_public_key(self: @TState) -> EthPublicKey;
    fn set_public_key(ref self: TState, new_public_key: EthPublicKey);

    // ISRC6CamelOnly
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IEthPublicKeyCamel
    fn getPublicKey(self: @TState) -> EthPublicKey;
    fn setPublicKey(ref self: TState, newPublicKey: EthPublicKey);

    // IUpgradeable
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
}
