use starknet::ClassHash;

#[starknet::interface]
trait IUpgradeable<TState> {
    fn upgrade(ref self: TState, impl_hash: ClassHash);
    fn upgrade_and_call(
        ref self: TState, impl_hash: ClassHash, selector: felt252, calldata: Span<felt252>
    );
}
