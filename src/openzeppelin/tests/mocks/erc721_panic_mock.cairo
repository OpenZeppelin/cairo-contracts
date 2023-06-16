// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// zero for ContractAddress
// u256 { 3, 3 } for u256

#[contract]
mod SnakeERC721PanicMock {
    use openzeppelin::utils::serde::SpanSerde;
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    //
    // agnostic
    //

    #[view]
    fn name() -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn symbol() -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external]
    fn approve(to: ContractAddress, token_id: u256) {
        panic_with_felt252('Some error');
    }

    //
    // snake
    //

    #[view]
    fn token_uri(token_id: u256) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[view]
    fn owner_of(token_id: u256) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[view]
    fn get_approved(token_id: u256) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[view]
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external]
    fn set_approval_for_all(operator: ContractAddress, approved: bool) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn safe_transfer_from(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) {
        panic_with_felt252('Some error');
    }
}

#[contract]
mod CamelERC721PanicMock {
    use openzeppelin::utils::serde::SpanSerde;
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[view]
    fn tokenUri(tokenId: u256) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[view]
    fn ownerOf(tokenId: u256) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[view]
    fn getApproved(tokenId: u256) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[view]
    fn isApprovedForAll(owner: ContractAddress, operator: ContractAddress) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external]
    fn setApprovalForAll(operator: ContractAddress, approved: bool) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn transferFrom(from: ContractAddress, to: ContractAddress, tokenId: u256) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn safeTransferFrom(
        from: ContractAddress, to: ContractAddress, tokenId: u256, data: Span<felt252>
    ) {
        panic_with_felt252('Some error');
    }
}
