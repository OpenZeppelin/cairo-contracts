#[starknet::contract]
mod ERC721 {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

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

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

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

    mod Errors {
        const UNEQUAL_ARRAYS: felt252 = 'Array lengths do not match';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        recipient: ContractAddress,
        token_ids: Array<u256>,
        token_uris: Array<felt252>
    ) {
        self.erc721.initializer(name, symbol);
        self._mint_assets(recipient, token_ids, token_uris);
    }

    /// Mints `token_ids` to `recipient`.
    /// Sets the token URI from `token_uris` to the corresponding
    /// token ID of `token_ids`.
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _mint_assets(
            ref self: ContractState,
            recipient: ContractAddress,
            token_ids: Array<u256>,
            token_uris: Array<felt252>
        ) {
            assert(token_ids.len() == token_uris.len(), Errors::UNEQUAL_ARRAYS);
            let mut ids_span = token_ids.span();
            let mut uris_span = token_uris.span();

            loop {
                if ids_span.len() == 0 {
                    break ();
                }
                let id = *ids_span.pop_front().unwrap();
                let uri = *uris_span.pop_front().unwrap();

                self.erc721._mint(recipient, id);
                self.erc721._set_token_uri(id, uri);
            }
        }
    }
}
