// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.1 (presets/erc1155.cairo)

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

    /// Sets the token `name`, `symbol` and `URI`.
    /// Mints the `values` for `token_ids` tokens to `recipient`.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        token_uri: ByteArray,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>
    ) {
        self.erc1155.initializer(name, symbol, token_uri);
        self.erc1155.safe_batch_mint(recipient, token_ids, values, array![].span());
    }
}
