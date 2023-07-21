// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// zero for ContractAddress
// u256 { 3, 3 } for u256

#[starknet::contract]
mod SnakeERC721PanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn symbol(self: @ContractState) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external(v0)]
    fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[external(v0)]
    fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external(v0)]
    fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external(v0)]
    fn is_approved_for_all(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external(v0)]
    fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn transfer_from(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    ) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn safe_transfer_from(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) {
        panic_with_felt252('Some error');
    }
}

#[starknet::contract]
mod CamelERC721PanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external(v0)]
    fn tokenUri(self: @ContractState, tokenId: u256) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[external(v0)]
    fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external(v0)]
    fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external(v0)]
    fn isApprovedForAll(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external(v0)]
    fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn transferFrom(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
    ) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn safeTransferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) {
        panic_with_felt252('Some error');
    }
}
