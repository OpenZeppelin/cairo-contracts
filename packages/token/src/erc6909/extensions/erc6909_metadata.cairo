// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc6909/extensions/erc6909_votes.cairo)

use starknet::ContractAddress;

/// # ERC6909Metadata Component
///
/// The ERC6909Metadata component allows to set metadata to the individual token IDs.
/// The internal function `_update_token_metadata` should be used inside the ERC6909 Hooks.
#[starknet::component]
pub mod ERC6909MetadataComponent {
    use core::num::traits::Zero;
    use openzeppelin_token::erc6909::ERC6909Component;
    use openzeppelin_token::erc6909::interface;
    use starknet::ContractAddress;
    use starknet::storage::Map;

    #[storage]
    struct Storage {
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
        +Drop<TContractState>
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
        impl ERC6909: ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Updates the metadata of a token ID.
        fn _update_token_metadata(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            id: u256,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8
        ) {
            let zero_address = Zero::zero();

            // In case of new ID mints update the token metadata
            if (sender == zero_address) {
                let token_metadata_exists = self._token_metadata_exists(id);
                if (!token_metadata_exists) {
                    self._set_token_metadata(id, name, symbol, decimals)
                }
            }
        }

        /// Checks if a token has metadata at the time of minting.
        fn _token_metadata_exists(self: @ComponentState<TContractState>, id: u256) -> bool {
            return self.ERC6909Metadata_name.read(id).len() > 0;
        }

        /// Updates the token metadata for `id`.
        fn _set_token_metadata(
            ref self: ComponentState<TContractState>,
            id: u256,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8
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
            ref self: ComponentState<TContractState>, id: u256, symbol: ByteArray
        ) {
            self.ERC6909Metadata_symbol.write(id, symbol);
        }

        /// Sets the token decimals.
        fn _set_token_decimals(ref self: ComponentState<TContractState>, id: u256, decimals: u8) {
            self.ERC6909Metadata_decimals.write(id, decimals);
        }
    }
}
