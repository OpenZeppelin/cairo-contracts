pub mod call_impls;
use core::hash::{HashStateTrait, HashStateExTrait, Hash};

/// Hash trait implementation for a span of elements.
pub impl HashSpanImpl<
    S, T, +HashStateTrait<S>, +Drop<S>, +Copy<T>, +Hash<T, S>
> of Hash<Span<T>, S> {
    fn update_state(mut state: S, value: Span<T>) -> S {
        state = state.update_with(value.len());
        for elem in value {
            state = state.update_with(*elem);
        };

        state
    }
}
