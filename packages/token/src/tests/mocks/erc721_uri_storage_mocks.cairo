#[starknet::contract]
pub(crate) mod ERC721URIStorageMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::extensions::ERC721URIStorageComponent;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(
        path: ERC721URIStorageComponent, storage: erc721_uri_storage, event: ERC721URIStorageEvent
    );
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721URIStorage
    #[abi(embed_v0)]
    impl ERC721URIStorageImpl =
        ERC721URIStorageComponent::ERC721URIStorageImpl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_uri_storage: ERC721URIStorageComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721URIStorageEvent: ERC721URIStorageComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721.mint(recipient, token_id);
    }
}
