#[starknet::interface]
pub trait IInitializable<TState> {
    fn is_initialized(self: @TState) -> bool;
}

#[starknet::interface]
pub trait IPausable<TState> {
    fn is_paused(self: @TState) -> bool;
}
