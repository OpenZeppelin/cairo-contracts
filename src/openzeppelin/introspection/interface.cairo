const ISRC5_ID: felt252 = 0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055;

#[starknet::interface]
trait ISRC5<TState> {
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::interface]
trait ISRC5Camel<TState> {
    fn supportsInterface(self: @TState, interfaceId: felt252) -> bool;
}

#[starknet::interface]
trait RegisterTrait<TState> {
    fn register_interface(ref self: TState, interface_id: felt252);
    fn deregister_interface(ref self: TState, interface_id: felt252);
}

#[starknet::interface]
trait RegisterCamelTrait<TState> {
    fn registerInterface(ref self: TState, interfaceId: felt252);
    fn deregisterInterface(ref self: TState, interfaceId: felt252);
}
