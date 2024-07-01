// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc721/extensions/erc721_uri_storage.cairo)

#[starknet::component]
pub mod ERC721URIstorageComponent {
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component,ERC721HooksEmptyImpl};
    use openzeppelin::token::erc721::ERC721Component::InternalImpl as ERC721Impl;
    use openzeppelin::token::erc721::interface::{IERC721,IERC721Metadata};
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
        pub token_id: u256,
    }

    #[embeddable_as(ERC721URIstorageImpl)]
    impl ERC721URIstorage<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721Metadata<ComponentState<TContractState>> {

        fn name(self:@ComponentState<TContractState>)->ByteArray{
            self._name()
        }
        
        fn symbol(self:@ComponentState<TContractState>)->ByteArray{
            self._symbol()
        }
        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        /// If the URI is not set, the return value will be an empty ByteArray.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn token_uri(self: @ComponentState<TContractState>,token_id:u256)->ByteArray{
            self._token_uri(token_id)
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
        +Drop<TContractState>
    > of InternalTrait<TContractState> {

        fn _name(self:@ComponentState<TContractState>)->ByteArray{
            let erc721_component= get_dep_component!(self, ERC721);
            let name=erc721_component.ERC721_name.read();
            return name;
        }
        
        fn _symbol(self:@ComponentState<TContractState>)->ByteArray{
            let erc721_component= get_dep_component!(self, ERC721);
            let symbol=erc721_component.ERC721_symbol.read();
            return symbol;
        }

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

            //token_uri implementation from the ERC721Metadata
            if base_uri.len() == 0 {
                return "";
            } else {
                return format!("{}{}", base_uri, token_id);
            }
        }

        /// Sets or updates the `token_uri` for the respective `token_uri`
        ///
        /// Emits `MetadataUpdate` event
        fn set_token_uri(ref self: ComponentState<TContractState>,token_id:u256,token_uri:ByteArray){
            self.token_uris.write(token_id,token_uri);
            self.emit(MetadataUpdate{token_id:token_id});
        }
    }
}