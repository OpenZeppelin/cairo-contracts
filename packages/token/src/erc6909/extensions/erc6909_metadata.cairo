// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc6909/extensions/erc6909_votes.cairo)

use starknet::ContractAddress;

/// # ERC6909Metadata Component
///
/// The ERC6909Metadata component allows to set metadata to the individual token IDs.
#[starknet::component]
pub mod ERC6909MetadataComponent {
    use openzeppelin::token::erc6909::ERC6909Component;
    use openzeppelin::token::erc6909::interface;

    #[storage]
    struct Storage {
        ERC6909Metadata_name: LegacyMap<u256, ByteArray>,
        ERC6909Metadata_symbol: LegacyMap<u256, ByteArray>,
        ERC6909Metadata_decimals: LegacyMap<u256, u8>,
    }

    #[embeddable_as(ERC6909MetadataImpl)]
    impl ERC6909Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>
    > of interface::IERC6909Metadata<ComponentState<TContractState>> {
        /// @notice Name of a given token.
        /// @param id The id of the token.
        /// @return The name of the token.
        fn name(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909Metadata_name.read(id)
        }

        /// @notice Symbol of a given token.
        /// @param id The id of the token.
        /// @return The symbol of the token.
        fn symbol(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909Metadata_symbol.read(id)
        }

        /// @notice Decimals of a given token.
        /// @param id The id of the token.
        /// @return The decimals of the token.
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
