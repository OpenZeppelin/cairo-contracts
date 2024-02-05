#[starknet::contract]
mod DualCaseERC1155Mock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155Component;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // ERC1155
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataImpl = ERC1155Component::ERC1155MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC1155Component::ERC1155CamelOnlyImpl<ContractState>;

    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
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
        value: u256,
        uri: ByteArray
    ) {
        self.erc1155.initializer(name, symbol, uri);

        // mint
        let token_ids = array![token_id].span();
        let values = array![value].span();
        self.erc1155.update(Zeroable::zero(), recipient, token_ids, values);
    }
}

#[starknet::contract]
mod SnakeERC1155Mock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155Component;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // ERC1155
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataImpl = ERC1155Component::ERC1155MetadataImpl<ContractState>;

    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
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
        value: u256,
        uri: ByteArray
    ) {
        self.erc1155.initializer(name, symbol, uri);

        // mint
        let token_ids = array![token_id].span();
        let values = array![value].span();
        self.erc1155.update(Zeroable::zero(), recipient, token_ids, values);
    }
}

#[starknet::contract]
mod CamelERC1155Mock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155Component::{ERC1155Impl, ERC1155MetadataImpl};
    use openzeppelin::token::erc1155::ERC1155Component;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // ERC1155
    #[abi(embed_v0)]
    impl ERC1155CamelOnly = ERC1155Component::ERC1155CamelOnlyImpl<ContractState>;

    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
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
        value: u256,
        uri: ByteArray
    ) {
        self.erc1155.initializer(name, symbol, uri);

        // mint
        let token_ids = array![token_id].span();
        let values = array![value].span();
        self.erc1155.update(Zeroable::zero(), recipient, token_ids, values);
    }

    /// The following external methods are included because they are case-agnostic
    /// and this contract should not embed the snake_case impl.
    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn name(self: @ContractState) -> ByteArray {
            self.erc1155.name()
        }

        #[external(v0)]
        fn symbol(self: @ContractState) -> ByteArray {
            self.erc1155.symbol()
        }
    }
}

#[starknet::contract]
mod SnakeERC1155PanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn name(self: @ContractState) -> ByteArray {
            panic!("Some error");
            "3"
        }

        #[external(v0)]
        fn symbol(self: @ContractState) -> ByteArray {
            panic!("Some error");
            "3"
        }

        #[external(v0)]
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn uri(self: @ContractState, token_id: u256) -> ByteArray {
            panic!("Some error");
            "3"
        }

        #[external(v0)]
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            panic!("Some error");
            u256 { low: 3, high: 3 }
        }

        #[external(v0)]
        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            panic!("Some error");
        }

        #[external(v0)]
        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            panic!("Some error");
        }

        #[external(v0)]
        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            panic!("Some error");
        }

        #[external(v0)]
        fn balance_of_batch(
            self: @ContractState, accounts: Span<ContractAddress>, token_ids: Span<u256>
        ) -> Span<u256> {
            panic!("Some error");
            array![u256 { low: 3, high: 3 }].span()
        }

        #[external(v0)]
        fn safe_batch_transfer_from(
            ref self: ContractState,
            from: starknet::ContractAddress,
            to: starknet::ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            panic!("Some error");
        }

        #[external(v0)]
        fn batch_transfer_from(
            ref self: ContractState,
            from: starknet::ContractAddress,
            to: starknet::ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>
        ) {
            panic!("Some error");
        }
    }
}

#[starknet::contract]
mod CamelERC1155PanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn name(self: @ContractState) -> ByteArray {
            panic!("Some error");
            "3"
        }

        #[external(v0)]
        fn symbol(self: @ContractState) -> ByteArray {
            panic!("Some error");
            "3"
        }

        #[external(v0)]
        fn uri(self: @ContractState, tokenId: u256) -> ByteArray {
            panic!("Some error");
            "3"
        }

        #[external(v0)]
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            panic!("Some error");
            u256 { low: 3, high: 3 }
        }

        #[external(v0)]
        fn isApprovedForAll(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            panic!("Some error");
            false
        }

        #[external(v0)]
        fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
            panic!("Some error");
        }

        #[external(v0)]
        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        ) {
            panic!("Some error");
        }

        #[external(v0)]
        fn safeTransferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            panic!("Some error");
        }

        #[external(v0)]
        fn balanceOfBatch(
            self: @ContractState, accounts: Span<ContractAddress>, token_ids: Span<u256>
        ) -> Span<u256> {
            panic!("Some error");
            array![u256 { low: 3, high: 3 }].span()
        }

        #[external(v0)]
        fn safeBatchTransferFrom(
            ref self: ContractState,
            from: starknet::ContractAddress,
            to: starknet::ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            panic!("Some error");
        }

        #[external(v0)]
        fn batchTransferFrom(
            ref self: ContractState,
            from: starknet::ContractAddress,
            to: starknet::ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>
        ) {
            panic!("Some error");
        }
    }
}
