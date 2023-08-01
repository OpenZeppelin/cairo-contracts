// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (introspection/interface.cairo)

const ISRC5_ID: felt252 = 0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055;

#[starknet::interface]
trait ISRC5<TState> {
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::interface]
trait ISRC5Camel<TState> {
    fn supportsInterface(self: @TState, interfaceId: felt252) -> bool;
}
