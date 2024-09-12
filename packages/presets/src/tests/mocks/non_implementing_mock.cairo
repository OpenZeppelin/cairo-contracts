#[starknet::contract]
pub(crate) mod NonImplementingMock {
    #[storage]
    pub struct Storage {}

    #[external(v0)]
    fn nope(self: @ContractState) -> bool {
        false
    }
}
