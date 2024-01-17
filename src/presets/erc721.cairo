// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (presets/erc721.cairo)

/// # ERC721 Preset
///
/// The ERC721 contract offers a batch-mint mechanism that
/// can only be executed once upon contract construction.
#[starknet::contract]
mod ERC721 {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
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

    mod Errors {
        const UNEQUAL_ARRAYS: felt252 = 'Array lengths do not match';
    }

    /// Sets the token `name` and `symbol`.
    /// Mints the `token_ids` tokens to `recipient` and sets
    /// each token's URI.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        token_uris: Span<felt252>
    ) {
        self.erc721.initializer(name, symbol);
        self._mint_assets(recipient, token_ids, token_uris);
    }

    /// Mints `token_ids` to `recipient`.
    /// Sets the token URI from `token_uris` to the corresponding
    /// token ID of `token_ids`.
    ///
    /// Requirements:
    ///
    /// - `token_ids` must be equal in length to `token_uris`.
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _mint_assets(
            ref self: ContractState,
            recipient: ContractAddress,
            mut token_ids: Span<u256>,
            mut token_uris: Span<felt252>
        ) {
            assert(token_ids.len() == token_uris.len(), Errors::UNEQUAL_ARRAYS);

            loop {
                if token_ids.len() == 0 {
                    break;
                }
                let id = *token_ids.pop_front().unwrap();
                let uri = *token_uris.pop_front().unwrap();

                self.erc721._mint(recipient, id);
                self.erc721._set_token_uri(id, uri);
            }
        }
    }
}
