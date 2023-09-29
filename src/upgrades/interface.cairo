use starknet::ClassHash;

#[starknet::interface]
trait IUpgradeable<TState> {
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
}
