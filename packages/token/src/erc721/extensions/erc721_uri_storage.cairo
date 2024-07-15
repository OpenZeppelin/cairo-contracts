// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.0-rc.0 (token/erc721/extensions/erc721_uri_storage.cairo)

/// # ERC721URIStorage Component
///
/// The ERC721URIStorage component provides a flexible IERC721Metadata implementation that enables
/// storage-based token URI management.
#[starknet::component]
pub mod ERC721URIStorageComponent {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component::InternalImpl as ERC721Impl;
    use openzeppelin::token::erc721::interface::IERC721Metadata;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        ERC721URIStorage_token_uris: Map<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        MetadataUpdated: MetadataUpdated,
    }

    /// Emitted when `token_uri` is changed for `token_id`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct MetadataUpdated {
        pub token_id: u256,
    }

    #[embeddable_as(ERC721URIStorageImpl)]
    impl ERC721URIStorage<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721Metadata<ComponentState<TContractState>> {
        /// Returns the NFT name.
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            let erc721_component = get_dep_component!(self, ERC721);
            erc721_component.ERC721_name.read()
        }

        /// Returns the NFT symbol.
        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            let erc721_component = get_dep_component!(self, ERC721);
            erc721_component.ERC721_symbol.read()
        }


        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> ByteArray {
            let mut erc721_component = get_dep_component!(self, ERC721);
            erc721_component._require_owned(token_id);
            let base_uri: ByteArray = ERC721Impl::_base_uri(erc721_component);
            let token_uri: ByteArray = self.ERC721URIStorage_token_uris.read(token_id);

            // If there is no base_uri, return the token_uri
            if base_uri.len() == 0 {
                return token_uri;
            }

            // If both are set, concatenate the base_uri and token_uri
            if token_uri.len() > 0 {
                return format!("{}{}", base_uri, token_uri);
            }

            // Implementation from ERC721Metadata::token_uri
            return format!("{}{}", base_uri, token_id);
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Sets or updates the `token_uri` for the respective `token_id`.
        ///
        /// Emits `MetadataUpdated` event.
        fn set_token_uri(
            ref self: ComponentState<TContractState>, token_id: u256, token_uri: ByteArray
        ) {
            self.ERC721URIStorage_token_uris.write(token_id, token_uri);
            self.emit(MetadataUpdated { token_id: token_id });
        }
    }
}
