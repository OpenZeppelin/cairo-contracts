// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.0
// (token/src/erc1155/extensions/erc1155_uri_storage.cairo)

/// # ERC1155URIStorage Component
///
/// Extension of ERC1155 that allows setting individual URIs for each token type.
/// This extension overrides the default `uri` behavior from ERC1155MetadataURI
/// to return per-token URIs when set, falling back to the base URI pattern
/// when a token URI is not explicitly set.
///
/// NOTE: Implementing ERC1155Component is a requirement for this component to be implemented.
#[starknet::component]
pub mod ERC1155URIStorageComponent {
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::erc1155::ERC1155Component;
    use crate::erc1155::ERC1155Component::URI;

    #[storage]
    pub struct Storage {
        pub ERC1155URIStorage_base_uri: ByteArray,
        pub ERC1155URIStorage_token_uris: Map<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    /// Provides a modified implementation of `uri` that returns per-token URIs
    /// when set, and falls back to the base ERC1155 URI otherwise.
    ///
    /// This implementation should be used instead of the default `ERC1155TokenURIDefaultImpl`
    /// when the ERC1155URIStorage extension is being used.
    pub impl ERC1155URIStorageImpl<
        TContractState,
        impl ERC1155URIStorage: HasComponent<TContractState>,
        +ERC1155Component::HasComponent<TContractState>,
        +ERC1155Component::ERC1155HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ERC1155Component::ERC1155TokenURITrait<TContractState> {
        /// Returns the Uniform Resource Identifier (URI) for `token_id` token.
        ///
        /// If a specific token URI is set for `token_id`, it returns the concatenation
        /// of the base URI and the token-specific URI.
        /// Otherwise, it falls back to the base ERC1155 URI.
        fn uri(
            self: @ERC1155Component::ComponentState<TContractState>, token_id: u256,
        ) -> ByteArray {
            let contract = self.get_contract();
            let erc1155_uri = ERC1155URIStorage::get_component(contract);
            let token_uri = erc1155_uri.ERC1155URIStorage_token_uris.read(token_id);

            // If token URI is set, concatenate base URI and token URI
            if token_uri.len() > 0 {
                let base_uri = erc1155_uri.ERC1155URIStorage_base_uri.read();
                format!("{}{}", base_uri, token_uri)
            } else {
                // Fall back to ERC1155 default URI
                self.ERC1155_uri.read()
            }
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC1155: ERC1155Component::HasComponent<TContractState>,
        +ERC1155Component::ERC1155HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Sets `token_uri` as the token URI of `token_id`.
        ///
        /// Emits a `URI` event.
        fn set_token_uri(
            ref self: ComponentState<TContractState>, token_id: u256, token_uri: ByteArray,
        ) {
            self.ERC1155URIStorage_token_uris.write(token_id, token_uri);

            let mut erc1155 = get_dep_component_mut!(ref self, ERC1155);
            erc1155.emit(URI { value: erc1155.uri(token_id), id: token_id });
        }

        /// Sets `base_uri` as the base URI for all tokens.
        fn set_base_uri(ref self: ComponentState<TContractState>, base_uri: ByteArray) {
            self.ERC1155URIStorage_base_uri.write(base_uri);
        }
    }
}
