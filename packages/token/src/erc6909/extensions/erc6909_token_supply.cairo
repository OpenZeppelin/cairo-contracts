// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc6909/extensions/erc6909_votes.cairo)

use starknet::ContractAddress;

/// # ERC6909TokenSupply Component
///
/// The ERC6909TokenSupply component allows to keep track of individual token ID supplies.
/// The internal function `_update_token_supply` should be used inside the ERC6909 Hooks.
#[starknet::component]
pub mod ERC6909TokenSupplyComponent {
    use core::num::traits::Zero;
    use openzeppelin_token::erc6909::ERC6909Component;
    use openzeppelin_token::erc6909::interface;
    use starknet::ContractAddress;
    use starknet::storage::Map;

    #[storage]
    struct Storage {
        ERC6909TokenSupply_total_supply: Map<u256, u256>,
    }

    #[embeddable_as(ERC6909TokenSupplyImpl)]
    impl ERC6909TokenSupply<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>
    > of interface::IERC6909TokenSupply<ComponentState<TContractState>> {
        /// Returns the total supply of a token.
        fn total_supply(self: @ComponentState<TContractState>, id: u256) -> u256 {
            self.ERC6909TokenSupply_total_supply.read(id)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC6909: ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Updates the total supply of a token ID.
        /// Ideally this function should be called in a `before_update` or `after_update`
        /// hook during mints and burns.
        fn _update_token_supply(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) {
            // In case of mints we increase the total supply of this token ID
            if (sender.is_zero()) {
                let total_supply = self.ERC6909TokenSupply_total_supply.read(id);
                self.ERC6909TokenSupply_total_supply.write(id, total_supply + amount);
            }

            // In case of burns we decrease the total supply of this token ID
            if (receiver.is_zero()) {
                let total_supply = self.ERC6909TokenSupply_total_supply.read(id);
                self.ERC6909TokenSupply_total_supply.write(id, total_supply - amount);
            }
        }
    }
}
