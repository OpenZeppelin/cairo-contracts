#[starknet::interface]
trait IInitializable<TState> {
    fn is_initialized(self: @TState) -> bool;
}

#[starknet::interface]
trait IPausable<TState> {
    fn is_paused(self: @TState) -> bool;
}
