use openzeppelin_interfaces::src9::OutsideExecution;
use starknet::ClassHash;
use starknet::account::Call;

#[starknet::interface]
pub trait MultisigAccountUpgradeableABI<TState> {
    // ISRC6
    fn __execute__(self: @TState, calls: Array<Call>);
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // ISRC9
    fn execute_from_outside_v2(
        ref self: TState, outside_execution: OutsideExecution, signature: Span<felt252>,
    ) -> Array<Span<felt252>>;
    fn is_valid_outside_execution_nonce(self: @TState, nonce: felt252) -> bool;

    // IDeclarer
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;

    // IMultisigDeployable
    fn __validate_deploy__(
        self: @TState,
        class_hash: felt252,
        contract_address_salt: felt252,
        quorum: u32,
        signers: Span<felt252>,
    ) -> felt252;

    // IMultisigAccount
    fn get_quorum(self: @TState) -> u32;
    fn is_signer(self: @TState, signer: felt252) -> bool;
    fn get_signers(self: @TState) -> Span<felt252>;
    fn add_signers(ref self: TState, new_quorum: u32, signers_to_add: Span<felt252>);
    fn remove_signers(ref self: TState, new_quorum: u32, signers_to_remove: Span<felt252>);
    fn replace_signer(ref self: TState, signer_to_remove: felt252, signer_to_add: felt252);
    fn change_quorum(ref self: TState, new_quorum: u32);

    // ISRC6CamelOnly
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;

    // IUpgradeable
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
}
