#[starknet::contract]
mod DualCaseERC721Mock {
    use openzeppelin::token::erc721::ERC721 as erc721_component;
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    component!(path: erc721_component, storage: erc721, event: ERC721Event);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC721Impl = erc721_component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = erc721_component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly =
        erc721_component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly = erc721_component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = erc721_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: erc721_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC721Event: erc721_component::Event,
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, symbol: felt252, token_id: u256, uri: felt252
    ) {
        self.erc721.initializer(name, symbol);
        self.erc721._mint(get_caller_address(), token_id);
        self.erc721._set_token_uri(token_id, uri);
    }
}

#[starknet::contract]
mod SnakeERC721Mock {
    use openzeppelin::token::erc721::ERC721 as erc721_component;
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    component!(path: erc721_component, storage: erc721, event: ERC721Event);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC721Impl = erc721_component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = erc721_component::ERC721MetadataImpl<ContractState>;
    impl InternalImpl = erc721_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: erc721_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC721Event: erc721_component::Event,
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, symbol: felt252, token_id: u256, uri: felt252
    ) {
        self.erc721.initializer(name, symbol);
        self.erc721._mint(get_caller_address(), token_id);
        self.erc721._set_token_uri(token_id, uri);
    }
}

#[starknet::contract]
mod CamelERC721Mock {
    use openzeppelin::token::erc721::ERC721::{ERC721Impl, ERC721MetadataImpl};
    use openzeppelin::token::erc721::ERC721 as erc721_component;
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    component!(path: erc721_component, storage: erc721, event: ERC721Event);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC721CamelOnly =
        erc721_component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly = erc721_component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl InternalImpl = erc721_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: erc721_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC721Event: erc721_component::Event,
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, symbol: felt252, token_id: u256, uri: felt252
    ) {
        self.erc721.initializer(name, symbol);
        self.erc721._mint(get_caller_address(), token_id);
        self.erc721._set_token_uri(token_id, uri);
    }

    /// The following external methods are included because they are case-agnostic
    /// and this contract should not embed the snake_case impl.
    #[external(v0)]
    fn approve(ref self: ContractState, to: ContractAddress, tokenId: u256) {
        self.erc721.approve(to, tokenId);
    }

    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        self.erc721.name()
    }

    #[external(v0)]
    fn symbol(self: @ContractState) -> felt252 {
        self.erc721.symbol()
    }
}

/// Although these modules are designed to panic, functions
/// still need a valid return value. We chose:
///
/// 3 for felt252
/// zero for ContractAddress
/// u256 { 3, 3 } for u256
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
    fn tokenURI(self: @ContractState, tokenId: u256) -> felt252 {
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
