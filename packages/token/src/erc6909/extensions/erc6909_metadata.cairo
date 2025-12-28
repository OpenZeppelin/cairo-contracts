// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc6909/extensions/erc6909_metadata.cairo)

/// # ERC6909Metadata Component
///
/// The ERC6909Metadata component allows setting metadata (name, symbol, decimals) for
/// individual token IDs. Unlike ERC20, ERC6909 supports multiple token types each with
/// its own metadata.
///
/// To use this component:
///
/// 1. Call `initializer` in your contract's constructor to register the SRC5 interface.
/// 2. Implement `ERC6909HooksTrait` in your contract.
/// 3. In the `after_update` hook, call `_update_token_metadata` with the desired metadata.
///    This function only sets metadata when `sender` is zero (indicating a mint) and the
///    token ID doesn't already have metadata, preventing overwrites on subsequent mints.
/// 4. For direct metadata control, use `_set_token_metadata` or the individual setters
///    `_set_token_name`, `_set_token_symbol`, and `_set_token_decimals`.
#[starknet::component]
pub mod ERC6909MetadataComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc6909 as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc6909::ERC6909Component;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    pub struct Storage {
        ERC6909Metadata_name: Map<u256, ByteArray>,
        ERC6909Metadata_symbol: Map<u256, ByteArray>,
        ERC6909Metadata_decimals: Map<u256, u8>,
    }

    #[embeddable_as(ERC6909MetadataImpl)]
    impl ERC6909Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909Metadata<ComponentState<TContractState>> {
        /// Returns the name of a token ID
        fn name(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909Metadata_name.read(id)
        }

        /// Returns the symbol of a token ID
        fn symbol(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909Metadata_symbol.read(id)
        }

        /// Returns the decimals of a token ID
        fn decimals(self: @ComponentState<TContractState>, id: u256) -> u8 {
            self.ERC6909Metadata_decimals.read(id)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by declaring support for the `IERC6909Metadata`
        /// interface id.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC6909_METADATA_ID);
        }

        /// Updates the metadata of a token ID.
        fn _update_token_metadata(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            id: u256,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
        ) {
            // In case of new ID mints update the token metadata
            if sender.is_zero() {
                if !self._token_metadata_exists(id) {
                    self._set_token_metadata(id, name, symbol, decimals)
                }
            }
        }

        /// Checks if a token has metadata at the time of minting.
        fn _token_metadata_exists(self: @ComponentState<TContractState>, id: u256) -> bool {
            self.ERC6909Metadata_name.read(id).len() > 0
        }

        /// Updates the token metadata for `id`.
        fn _set_token_metadata(
            ref self: ComponentState<TContractState>,
            id: u256,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
        ) {
            self._set_token_name(id, name);
            self._set_token_symbol(id, symbol);
            self._set_token_decimals(id, decimals);
        }

        /// Sets the token name.
        fn _set_token_name(ref self: ComponentState<TContractState>, id: u256, name: ByteArray) {
            self.ERC6909Metadata_name.write(id, name);
        }

        /// Sets the token symbol.
        fn _set_token_symbol(
            ref self: ComponentState<TContractState>, id: u256, symbol: ByteArray,
        ) {
            self.ERC6909Metadata_symbol.write(id, symbol);
        }

        /// Sets the token decimals.
        fn _set_token_decimals(ref self: ComponentState<TContractState>, id: u256, decimals: u8) {
            self.ERC6909Metadata_decimals.write(id, decimals);
        }
    }
}
