#[starknet::contract]
mod DualCaseERC721Mock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
        uri: ByteArray
    ) {
        self.erc721.initializer(name, symbol);
        self.erc721._mint(recipient, token_id);
        self.erc721._set_token_uri(token_id, uri);
    }
}

#[starknet::contract]
mod SnakeERC721Mock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
        uri: ByteArray
    ) {
        self.erc721.initializer(name, symbol);
        self.erc721._mint(recipient, token_id);
        self.erc721._set_token_uri(token_id, uri);
    }
}

#[starknet::contract]
mod CamelERC721Mock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component::{ERC721Impl, ERC721MetadataImpl};
    use openzeppelin::token::erc721::ERC721Component;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
        uri: ByteArray
    ) {
        self.erc721.initializer(name, symbol);
        self.erc721._mint(recipient, token_id);
        self.erc721._set_token_uri(token_id, uri);
    }

    /// The following external methods are included because they are case-agnostic
    /// and this contract should not embed the snake_case impl.
    #[generate_trait]
    #[external(v0)]
    impl ExternalImpl of ExternalTrait {
        fn approve(ref self: ContractState, to: ContractAddress, tokenId: u256) {
            self.erc721.approve(to, tokenId);
        }

        fn name(self: @ContractState) -> ByteArray {
            self.erc721.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721.symbol()
        }
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

    #[generate_trait]
    #[external(v0)]
    impl ExternalImpl of ExternalTrait {
        fn name(self: @ContractState) {
            panic_with_felt252('Some error');
        }

        fn symbol(self: @ContractState) {
            panic_with_felt252('Some error');
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            panic_with_felt252('Some error');
        }

        fn supports_interface(self: @ContractState, interface_id: felt252) {
            panic_with_felt252('Some error');
        }

        fn token_uri(self: @ContractState, token_id: u256) {
            panic_with_felt252('Some error');
        }

        fn balance_of(self: @ContractState, account: ContractAddress) {
            panic_with_felt252('Some error');
        }

        fn owner_of(self: @ContractState, token_id: u256) {
            panic_with_felt252('Some error');
        }

        fn get_approved(self: @ContractState, token_id: u256) {
            panic_with_felt252('Some error');
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) {
            panic_with_felt252('Some error');
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            panic_with_felt252('Some error');
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            panic_with_felt252('Some error');
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: ByteArray
        ) {
            panic_with_felt252('Some error');
        }
    }
}

#[starknet::contract]
mod CamelERC721PanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[generate_trait]
    #[external(v0)]
    impl ExternalImpl of ExternalTrait {
        fn supportsInterface(self: @ContractState, interfaceId: felt252) {
            panic_with_felt252('Some error');
        }

        fn tokenURI(self: @ContractState, tokenId: u256) {
            panic_with_felt252('Some error');
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) {
            panic_with_felt252('Some error');
        }

        fn ownerOf(self: @ContractState, tokenId: u256) {
            panic_with_felt252('Some error');
        }

        fn getApproved(self: @ContractState, tokenId: u256) {
            panic_with_felt252('Some error');
        }

        fn isApprovedForAll(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            panic_with_felt252('Some error');
        }

        fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
            panic_with_felt252('Some error');
        }

        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        ) {
            panic_with_felt252('Some error');
        }

        fn safeTransferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: ByteArray
        ) {
            panic_with_felt252('Some error');
        }
    }
}
