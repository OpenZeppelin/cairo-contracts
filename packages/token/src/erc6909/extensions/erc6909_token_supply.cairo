// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0 (token/src/erc6909/extensions/erc6909_token_supply.cairo)

/// # ERC6909TokenSupply Component
///
/// The ERC6909TokenSupply component tracks the total supply for each individual token ID.
/// Since ERC6909 supports multiple token types within a single contract, each token ID
/// maintains its own supply counter.
///
/// To use this component:
///
/// 1. Call `initializer` in your contract's constructor to register the SRC5 interface.
/// 2. Implement `ERC6909HooksTrait` in your contract.
/// 3. In either `before_update` or `after_update` hook, call `_update_token_supply`.
///    This function automatically adjusts the supply: increasing it when `sender` is zero
///    (mint) and decreasing it when `receiver` is zero (burn). Regular transfers between
///    non-zero addresses do not affect the supply.
#[starknet::component]
pub mod ERC6909TokenSupplyComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc6909 as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc6909::ERC6909Component;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    pub struct Storage {
        ERC6909TokenSupply_total_supply: Map<u256, u256>,
    }

    #[embeddable_as(ERC6909TokenSupplyImpl)]
    impl ERC6909TokenSupply<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>,
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
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by declaring support for the `IERC6909TokenSupply`
        /// interface id.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC6909_TOKEN_SUPPLY_ID);
        }

        /// Updates the total supply of a token ID.
        /// Ideally this function should be called in a `before_update` or `after_update`
        /// hook during mints and burns.
        fn _update_token_supply(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            // In case of mints we increase the total supply of this token ID
            if sender.is_zero() {
                let total_supply = self.ERC6909TokenSupply_total_supply.read(id);
                self.ERC6909TokenSupply_total_supply.write(id, total_supply + amount);
            }

            // In case of burns we decrease the total supply of this token ID
            if receiver.is_zero() {
                let total_supply = self.ERC6909TokenSupply_total_supply.read(id);
                self.ERC6909TokenSupply_total_supply.write(id, total_supply - amount);
            }
        }
    }
}
