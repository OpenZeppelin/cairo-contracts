// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.2 (interfaces/src/utils/snip12.cairo)

#[starknet::interface]
pub trait ISNIP12Metadata<TState> {
    fn snip12_metadata(self: @TState) -> (felt252, felt252);
}
