// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (presets/erc1155.cairo)

/// # ERC1155 Preset
///
/// The ERC1155 contract offers a batch-mint mechanism that
/// can only be executed once upon contract construction.
#[starknet::contract]
mod ERC1155 {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155Component;
    use starknet::ContractAddress;

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataImpl = ERC1155Component::ERC1155MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155CamelOnly = ERC1155Component::ERC1155CamelOnlyImpl<ContractState>;

    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

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

    mod Errors {
        const UNEQUAL_ARRAYS_VALUES: felt252 = 'Values array len do not match';
        const UNEQUAL_ARRAYS_URI: felt252 = 'URI Array len do not match';
    }

    /// Sets the token `name` and `symbol`.
    /// Mints the `values` for `token_ids` tokens to `recipient` and sets
    /// each token's URI.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        token_uris: Span<felt252>
    ) {
        self.erc1155.initializer(name, symbol);
        self._mint_assets(recipient, token_ids, values, token_uris);
    }

    /// Mints the `values` for `token_ids` tokens to `recipient`.
    /// Sets the token URI from `token_uris` to the corresponding
    /// token ID of `token_ids`.
    ///
    /// Requirements:
    ///
    /// - `values` must be equal in length to `token_ids`.
    /// - `token_ids` must be equal in length to `token_uris`.
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _mint_assets(
            ref self: ContractState,
            recipient: ContractAddress,
            mut token_ids: Span<u256>,
            mut values: Span<u256>,
            mut token_uris: Span<felt252>
        ) {
            assert(token_ids.len() == values.len(), Errors::UNEQUAL_ARRAYS_VALUES);
            assert(token_ids.len() == token_uris.len(), Errors::UNEQUAL_ARRAYS_URI);

            loop {
                if token_ids.len() == 0 {
                    break;
                }
                let id = *token_ids.pop_front().unwrap();
                let value = *values.pop_front().unwrap();
                let uri = *token_uris.pop_front().unwrap();

                self.erc1155._mint(recipient, id, value);
                self.erc1155._set_uri(id, uri);
            }
        }
    }
}
