#[starknet::contract]
mod NonImplementingMock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn nope(self: @ContractState) -> bool {
        false
    }
}
