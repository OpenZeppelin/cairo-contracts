// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0
// (token/src/erc721/extensions/erc721_uri_storage.cairo)

/// # ERC721URIStorage Component
///
/// Extension of ERC721 that allows setting individual URIs for each token.
/// This extension overrides the default `token_uri` behavior from ERC721Metadata
/// to return per-token URIs when set, falling back to the base URI pattern
/// when a token URI is not explicitly set.
///
/// ## Usage
///
/// This extension requires implementing the ERC721HooksTrait to properly clean up
/// token URIs when tokens are burned. Here's an example implementation:
///
/// ```cairo
/// #[starknet::contract]
/// mod MyNFT {
///     use openzeppelin_introspection::src5::SRC5Component;
///     use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
///     use openzeppelin_token::erc721::extensions::ERC721URIStorageComponent;
///     use starknet::ContractAddress;
///
///     component!(path: ERC721Component, storage: erc721, event: ERC721Event);
///     component!(path: ERC721URIStorageComponent, storage: erc721_uri_storage, event:
///     ERC721URIStorageEvent);
///     component!(path: SRC5Component, storage: src5, event: SRC5Event);
///
///     // ERC721 Mixin
///     #[abi(embed_v0)]
///     impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
///     impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
///
///     // ERC721URIStorage
///     #[abi(embed_v0)]
///     impl ERC721URIStorageImpl = ERC721URIStorageComponent::ERC721URIStorageImpl<ContractState>;
///     impl ERC721URIStorageInternalImpl = ERC721URIStorageComponent::InternalImpl<ContractState>;
///
///     #[storage]
///     struct Storage {
///         #[substorage(v0)]
///         erc721: ERC721Component::Storage,
///         #[substorage(v0)]
///         erc721_uri_storage: ERC721URIStorageComponent::Storage,
///         #[substorage(v0)]
///         src5: SRC5Component::Storage
///     }
///
///     #[event]
///     #[derive(Drop, starknet::Event)]
///     enum Event {
///         #[flat]
///         ERC721Event: ERC721Component::Event,
///         #[flat]
///         ERC721URIStorageEvent: ERC721URIStorageComponent::Event,
///         #[flat]
///         SRC5Event: SRC5Component::Event
///     }
///
///     // Implement the ERC721 hooks to clean up URIs on burn
///     impl ERC721Hooks of ERC721Component::ERC721HooksTrait<ContractState> {
///         fn after_update(
///             ref self: ERC721Component::ComponentState<ContractState>,
///             to: ContractAddress,
///             token_id: u256,
///             auth: ContractAddress
///         ) {
///             let mut uri_storage_component = get_dep_component_mut!(ref self, ERC721URIStorage);
///             uri_storage_component.after_update(to, token_id, auth);
///         }
///     }
///
///     #[constructor]
///     fn constructor(ref self: ContractState) {
///         self.erc721.initializer("MyNFT", "MNFT", "https://example.com/token/");
///     }
///
///     #[generate_trait]
///     #[abi(per_item)]
///     impl ExternalImpl of ExternalTrait {
///         #[external(v0)]
///         fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
///             self.erc721.mint(to, token_id);
///         }
///
///         #[external(v0)]
///         fn set_token_uri(ref self: ContractState, token_id: u256, uri: ByteArray) {
///             // Add access control as needed
///             self.erc721_uri_storage._set_token_uri(token_id, uri);
///         }
///
///         // Override token_uri to use the URI storage implementation
///         #[external(v0)]
///         fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
///             self.erc721_uri_storage.token_uri(token_id)
///         }
///     }
/// }
/// ```
///
/// NOTE: Implementing ERC721Component is a requirement for this component to be implemented.
///
/// WARNING: To properly clean up token URIs, this extension requires that
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
        BatchMetadataUpdate: BatchMetadataUpdate,
    }

    /// Emitted when the metadata of a token is changed.
    /// See https://eips.ethereum.org/EIPS/eip-4906[ERC-4906] for details.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct MetadataUpdate {
        #[key]
        pub token_id: u256,
    }

    /// Emitted when the metadata of a range of tokens is changed.
    /// See https://eips.ethereum.org/EIPS/eip-4906[ERC-4906] for details.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct BatchMetadataUpdate {
        pub from_token_id: u256,
        pub to_token_id: u256,
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
            let erc721_uri_storage = ERC721URIStorage::get_component(contract);
            let erc721 = ERC721::get_component(contract);
            erc721._require_owned(token_id);

            let base_uri = erc721._base_uri();
            let suffix = erc721_uri_storage.ERC721URIStorage_token_uris.read(token_id);

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
            // If burning (to == 0), delete the token URI
            if to.is_zero() {
                self.ERC721URIStorage_token_uris.write(token_id, "");
            }
        }
    }
}
