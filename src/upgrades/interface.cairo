use starknet::ClassHash;

#[starknet::interface]
trait IUpgradeable<TState> {
    fn upgrade(ref self: TState, impl_hash: ClassHash);
}
