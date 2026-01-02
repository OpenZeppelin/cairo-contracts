// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0 (token/src/erc6909/extensions/erc6909_content_uri.cairo)

/// # ERC6909ContentURI Component
///
/// The ERC6909ContentURI component allows to set the contract and token ID URIs.
///
/// Call the `initializer` function in your contract's constructor to register the interface.
/// Use `_set_contract_uri` and `_set_token_uri` to set the URIs as needed.
#[starknet::component]
pub mod ERC6909ContentURIComponent {
    use openzeppelin_interfaces::erc6909 as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc6909::ERC6909Component;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        ERC6909ContentURI_contract_uri: ByteArray,
        ERC6909ContentURI_token_uris: Map<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        ContractURIUpdated: ContractURIUpdated,
        URI: URI,
    }

    /// Emitted when the contract URI is changed.
    /// See https://eips.ethereum.org/EIPS/eip-7572[ERC-7572] for details.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ContractURIUpdated {}

    /// Emitted when the URI for a token ID is changed.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct URI {
        pub value: ByteArray,
        #[key]
        pub id: u256,
    }

    #[embeddable_as(ERC6909ContentURIImpl)]
    impl ERC6909ContentURI<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909ContentUri<ComponentState<TContractState>> {
        /// Returns the contract level URI.
        fn contract_uri(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC6909ContentURI_contract_uri.read()
        }

        /// Returns the token level URI.
        fn token_uri(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909ContentURI_token_uris.read(id)
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
        +ERC6909Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by declaring support for the `IERC6909ContentUri` interface id.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC6909_CONTENT_URI_ID);
        }

        /// Sets the contract URI.
        ///
        /// Emits a `ContractURIUpdated` event.
        fn _set_contract_uri(ref self: ComponentState<TContractState>, contract_uri: ByteArray) {
            self.ERC6909ContentURI_contract_uri.write(contract_uri);
            self.emit(ContractURIUpdated {});
        }

        /// Sets the token URI for a given token ID.
        ///
        /// Emits a `URI` event.
        fn _set_token_uri(ref self: ComponentState<TContractState>, id: u256, token_uri: ByteArray) {
            self.ERC6909ContentURI_token_uris.write(id, token_uri.clone());
            self.emit(URI { value: token_uri, id });
        }
    }
}
