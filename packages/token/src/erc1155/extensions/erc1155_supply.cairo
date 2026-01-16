// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0
// (token/src/erc1155/extensions/erc1155_supply.cairo)

/// # ERC1155Supply Component
///
/// Extension of ERC1155 that adds tracking of total supply per id and in aggregate.
///
/// WARNING: This extension SHOULD NOT be added in an upgrade to an already deployed contract.
///
/// NOTE: Implementing ERC1155Component is a requirement for this component to be implemented.
///
/// WARNING: To properly track total supply, this extension requires that
/// the ERC1155SupplyComponent::after_update function is called after
/// every transfer, mint, or burn operation.
/// For this, the ERC1155HooksTrait::after_update hook must be used.
#[starknet::component]
pub mod ERC1155SupplyComponent {
    use core::iter::zip;
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc1155 as interface;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::erc1155::ERC1155Component;

    #[storage]
    pub struct Storage {
        pub ERC1155Supply_total_supply: Map<u256, u256>,
        pub ERC1155Supply_total_supply_all: u256,
    }

    #[embeddable_as(ERC1155SupplyImpl)]
    impl ERC1155Supply<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC1155: ERC1155Component::HasComponent<TContractState>,
        +ERC1155Component::ERC1155HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC1155Supply<ComponentState<TContractState>> {
        /// Returns the total supply for `token_id`.
        fn total_supply(self: @ComponentState<TContractState>, token_id: u256) -> u256 {
            self.ERC1155Supply_total_supply.read(token_id)
        }

        /// Returns the total supply across all token ids.
        fn total_supply_all(self: @ComponentState<TContractState>) -> u256 {
            self.ERC1155Supply_total_supply_all.read()
        }

        /// Returns whether any tokens exist for `token_id`.
        fn exists(self: @ComponentState<TContractState>, token_id: u256) -> bool {
            self.total_supply(token_id) > 0
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
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Updates total supply tracking after an ERC1155 update.
        ///
        /// This must be added to the implementing contract's `ERC1155HooksTrait::after_update`
        /// hook.
        fn after_update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {
            if from.is_zero() {
                let mut total_mint_value: u256 = 0;
                for (token_id, value) in zip(token_ids, values) {
                    let current_supply = self.ERC1155Supply_total_supply.read(*token_id);
                    self.ERC1155Supply_total_supply.write(*token_id, current_supply + *value);
                    total_mint_value += *value;
                }

                let total_supply_all = self.ERC1155Supply_total_supply_all.read();
                self.ERC1155Supply_total_supply_all.write(total_supply_all + total_mint_value);
            }

            if to.is_zero() {
                let mut total_burn_value: u256 = 0;
                for (token_id, value) in zip(token_ids, values) {
                    let current_supply = self.ERC1155Supply_total_supply.read(*token_id);
                    self.ERC1155Supply_total_supply.write(*token_id, current_supply - *value);
                    total_burn_value += *value;
                }

                let total_supply_all = self.ERC1155Supply_total_supply_all.read();
                self.ERC1155Supply_total_supply_all.write(total_supply_all - total_burn_value);
            }
        }
    }
}
