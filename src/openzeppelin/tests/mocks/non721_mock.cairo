#[starknet::contract]
mod NonERC721 {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn nope(self: @ContractState) -> bool {
        false
    }
}
