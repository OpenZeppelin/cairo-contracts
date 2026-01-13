// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0 (token/src/erc6909/extensions/erc6909_metadata.cairo)

/// # ERC6909Metadata Component
///
/// The ERC6909Metadata component allows setting metadata (name, symbol, decimals) for
/// individual token IDs. Unlike ERC20, ERC6909 supports multiple token types each with
/// its own metadata.
///
/// To use this component:
///
/// 1. Call `initializer` in your contract's constructor with the initial token metadata
///    (id, name, symbol, decimals) to register the SRC5 interface and set up the first token.
/// 2. For additional token IDs, use the individual setters `set_token_name`,
///    `set_token_symbol`, and `set_token_decimals` to configure metadata.
#[starknet::component]
pub mod ERC6909MetadataComponent {
    use openzeppelin_interfaces::erc6909 as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc6909::ERC6909Component;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    pub struct Storage {
        ERC6909Metadata_name: Map<u256, ByteArray>,
        ERC6909Metadata_symbol: Map<u256, ByteArray>,
        ERC6909Metadata_decimals: Map<u256, u8>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        ERC6909NameUpdated: ERC6909NameUpdated,
        ERC6909SymbolUpdated: ERC6909SymbolUpdated,
        ERC6909DecimalsUpdated: ERC6909DecimalsUpdated,
    }

    /// Emitted when the name of the token of type `id` was updated to `new_name`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ERC6909NameUpdated {
        #[key]
        pub id: u256,
        pub new_name: ByteArray,
    }

    /// Emitted when the symbol for the token of type `id` was updated to `new_symbol`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ERC6909SymbolUpdated {
        #[key]
        pub id: u256,
        pub new_symbol: ByteArray,
    }

    /// Emitted when the decimals value for token of type `id` was updated to `new_decimals`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ERC6909DecimalsUpdated {
        #[key]
        pub id: u256,
        pub new_decimals: u8,
    }

    #[embeddable_as(ERC6909MetadataImpl)]
    impl ERC6909Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909Metadata<ComponentState<TContractState>> {
        /// Returns the name for the token of type `id`
        fn name(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909Metadata_name.read(id)
        }

        /// Returns the symbol for the token of type `id`
        fn symbol(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909Metadata_symbol.read(id)
        }

        /// Returns the decimals for the token of type `id`
        fn decimals(self: @ComponentState<TContractState>, id: u256) -> u8 {
            self.ERC6909Metadata_decimals.read(id)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by declaring support for the `IERC6909Metadata`
        /// interface id and setting the initial token metadata.
        fn initializer(
            ref self: ComponentState<TContractState>,
            id: u256,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
        ) {
            self.set_token_name(id, name);
            self.set_token_symbol(id, symbol);
            self.set_token_decimals(id, decimals);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC6909_METADATA_ID);
        }

        /// Sets the token name.
        fn set_token_name(ref self: ComponentState<TContractState>, id: u256, name: ByteArray) {
            self.ERC6909Metadata_name.write(id, name.clone());
            self.emit(ERC6909NameUpdated { id, new_name: name })
        }

        /// Sets the token symbol.
        fn set_token_symbol(
            ref self: ComponentState<TContractState>, id: u256, symbol: ByteArray,
        ) {
            self.ERC6909Metadata_symbol.write(id, symbol.clone());
            self.emit(ERC6909SymbolUpdated { id, new_symbol: symbol });
        }

        /// Sets the token decimals.
        fn set_token_decimals(ref self: ComponentState<TContractState>, id: u256, decimals: u8) {
            self.ERC6909Metadata_decimals.write(id, decimals);
            self.emit(ERC6909DecimalsUpdated { id, new_decimals: decimals })
        }
    }
}
