// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.0
// (token/src/erc721/extensions/erc721_uri_storage.cairo)

/// # ERC721URIStorage Component
///
/// Extension of ERC721 that allows setting individual URIs for each token.
/// This extension overrides the default `token_uri` behavior from ERC721Metadata
/// to return per-token URIs when set, falling back to the base URI pattern
/// when a token URI is not explicitly set.
///
/// IMPORTANT: To properly clean up token URIs, this extension requires that
/// the ERC721URIStorageComponent::after_update function is called after
/// every burn operation.
/// For this, the ERC721HooksTrait::after_update hook must be used.
#[starknet::component]
pub mod ERC721URIStorageComponent {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::ERC721Component::{
        ERC721MetadataImpl, ERC721TokenURITrait, InternalImpl as ERC721InternalImpl,
    };
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    pub struct Storage {
        pub ERC721URIStorage_token_uris: Map<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        MetadataUpdate: MetadataUpdate,
    }

    /// Emitted when the metadata of a token is changed.
    /// See https://eips.ethereum.org/EIPS/eip-4906[ERC-4906] for details.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct MetadataUpdate {
        #[key]
        pub token_id: u256,
    }

    //
    // Token URI
    //

    /// Provides a modified implementation of `token_uri` that returns per-token URIs
    /// when set, and falls back to the base implementation otherwise.
    pub impl ERC721TokenURIStorageImpl<
        TContractState,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl ERC721URIStorage: HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +ERC721Component::ERC721TokenOwnerTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ERC721TokenURITrait<TContractState> {
        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        ///
        /// If a specific URI is set for `token_id`, it is returned.
        /// Otherwise, if a base URI is set, the concatenation of the base URI and the token ID
        /// is returned.
        /// If neither is set, an empty ByteArray is returned.
        ///
        /// Requirements:
        ///
        /// - `token_id` must exist.
        fn token_uri(
            self: @ERC721Component::ComponentState<TContractState>, token_id: u256,
        ) -> ByteArray {
            let contract = self.get_contract();
            let erc721_uri = ERC721URIStorage::get_component(contract);
            self._require_owned(token_id);

            let base_uri = self._base_uri();
            let suffix = erc721_uri.ERC721URIStorage_token_uris.read(token_id);

            if base_uri.len() == 0 {
                suffix
            } else if suffix.len() > 0 {
                format!("{}{}", base_uri, suffix)
            } else {
                format!("{}{}", base_uri, token_id)
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
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +ERC721Component::ERC721TokenOwnerTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Sets the URI for a specific token.
        ///
        /// Requirements:
        ///
        /// - `token_id` must exist.
        ///
        /// Emits a `MetadataUpdate` event.
        fn set_token_uri(
            ref self: ComponentState<TContractState>, token_id: u256, token_uri: ByteArray,
        ) {
            let mut erc721_component = get_dep_component!(@self, ERC721);
            erc721_component._require_owned(token_id);

            self.ERC721URIStorage_token_uris.write(token_id, token_uri);
            self.emit(MetadataUpdate { token_id });
        }

        /// Cleans up the token URI when a token is burned.
        ///
        /// This function should be called from the `ERC721HooksTrait::after_update`
        /// hook to ensure token URIs are properly cleaned up on burn.
        fn after_update(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // Delete URI for a burned token
            if to.is_zero() {
                self.ERC721URIStorage_token_uris.write(token_id, "");
            }
        }
    }
}
