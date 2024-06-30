// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc721/extensions/erc721_uri_storage.cairo)

#[starknet::component]
pub mod ERC721URIstorageComponent {
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component,ERC721HooksEmptyImpl,ERC721HooksTrait};
    use openzeppelin::token::erc721::ERC721Component::InternalImpl as ERC721Impl;
    use openzeppelin::token::erc721::ERC721Component::ERC721Metadata;
    use openzeppelin::token::erc721::interface::{IERC721,IERC721Metadata,IERC721URIstorage};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        token_uris:LegacyMap<u256,ByteArray>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        MetadataUpdate:MetadataUpdate,
    }

    /// Emitted when `token_uri` is changed for `token_id`
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct MetadataUpdate{
        #[key]
        token_id: u256,
    }

    #[embeddable_as(ERC721URIstorageImpl)]
    impl ERC721URIstorage<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +ERC721HooksTrait<TContractState>,
        +Drop<TContractState>
    > of IERC721URIstorage<ComponentState<TContractState>> {

        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        /// If the URI is not set, the return value will be an empty ByteArray.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn token_uri(self: @ComponentState<TContractState>,token_id:u256)->ByteArray{
            self._token_uri(token_id)
        }

        /// Sets the Uniform Resource Identifier (URI) for the `token_id` token.
        fn set_token_uri(ref self: ComponentState<TContractState>,token_id:u256,_token_uri:ByteArray){
            self._set_token_uri(token_id,_token_uri);
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl Hooks: ERC721HooksTrait<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {

        /// Returns the `token_uri` for the `token_id` 
        /// if needed, returns the concatenated string
        fn _token_uri(self: @ComponentState<TContractState>,token_id:u256)-> ByteArray{
            let mut erc721_component= get_dep_component!(self, ERC721);
            ERC721Impl::_require_owned(erc721_component,token_id);
            let base_uri:ByteArray=ERC721Impl::_base_uri(erc721_component);
            let token_uri:ByteArray= self.token_uris.read(token_id);
            if base_uri.len()==0{
                return token_uri;
            }
            if token_uri.len()>0{
                return format!("{}{}",base_uri,token_uri);
            }
            return ERC721Metadata::token_uri(erc721_component,token_id);
        }

        /// Sets or updates the `token_uri` for the respective `token_uri`
        ///
        /// Emits `MetadataUpdate` event
        fn _set_token_uri(ref self: ComponentState<TContractState>,token_id:u256,_token_uri:ByteArray){
            self.token_uris.write(token_id,_token_uri);
            self.emit(MetadataUpdate{token_id:token_id});
        }
    }
}


