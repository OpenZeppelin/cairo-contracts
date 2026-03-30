// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.0
// (token/src/erc20/extensions/erc20_flash_mint.cairo)

/// # ERC20 Flash Mint Component
///
/// Provides [ERC-3156](https://eips.ethereum.org/EIPS/eip-3156) compatible flash loan capabilities
/// to the ERC20 token.
/// Allows users to borrow tokens and return them (plus a customizable fee) within the same
/// transaction, using the Flash Mint pattern (minting tokens for the duration of the loan, burning
/// them after use).
///
/// Integrate this component into your ERC20 contract to enable single-transaction flash loans.
/// You may override the max loan, fee calculation, or fee recipient by extending the
/// `FlashMintConfigTrait`.
///
/// NOTE: When this extension is used along with the `ERC20Votes` extension,
/// `max_flash_loan` will not correctly reflect the maximum that can be flash minted. We advise
/// against combining this extension with the `ERC20Votes` extension. If you need to combine them,
/// you should override the flash mint config to correctly reflect the supply cap.
#[starknet::component]
pub mod ERC20FlashMintComponent {
    use core::num::traits::{Bounded, Zero};
    use openzeppelin_interfaces::erc20::IERC20;
    use openzeppelin_interfaces::token::erc3156::{
        IERC3156FlashBorrowerDispatcher, IERC3156FlashBorrowerDispatcherTrait, IERC3156FlashLender,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::erc20::ERC20Component;
    use crate::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;

    const ON_FLASH_LOAN_RETURN: felt252 = selector!("ERC3156FlashBorrower.onFlashLoan");

    pub mod Errors {
        /// Thrown if a requested token address does not match this contract's address.
        pub const UNSUPPORTED_TOKEN: felt252 = 'FlashMint: unsupported token';
        /// Thrown if the requested flash loan amount exceeds the allowed maximum.
        pub const EXCEEDED_MAX_LOAN: felt252 = 'FlashMint: exceeded max loan';
        /// Thrown if the receiver does not return the correct magic value.
        pub const INVALID_RECEIVER: felt252 = 'FlashMint: invalid receiver';
    }

    #[storage]
    pub struct Storage {}

    /// ## Flash Mint Configuration Trait
    ///
    /// Override to provide custom max flash loan calculations, flash fees, or fee receivers.
    pub trait FlashMintConfigTrait<TContractState, +HasComponent<TContractState>> {
        /// Returns the maximum amount of tokens available for flash loan.
        ///
        /// By default, this is the maximum value minus `total_supply`, if `token` matches this
        /// contract's address.
        fn max_flash_loan(
            self: @ComponentState<TContractState>, token: ContractAddress, total_supply: u256,
        ) -> u256 {
            let this = get_contract_address();
            if token != this {
                return 0;
            }
            Bounded::MAX - total_supply
        }

        /// Returns the fee to charge for a flash loan of `amount` tokens of `token`.
        ///
        /// The default implementation charges no fee.
        ///
        /// # Arguments
        /// - `token` - The token address requested for the flash loan
        /// - `amount` - The amount of tokens to be flash loaned
        ///
        /// # Returns
        /// - `u256` - The fee amount to be charged
        fn flash_fee(
            self: @ComponentState<TContractState>, token: ContractAddress, amount: u256,
        ) -> u256 {
            0
        }

        /// Returns the address that should receive the flash fee.
        ///
        /// The default implementation returns the zero address (fee is burnt).
        ///
        /// # Returns
        /// - `ContractAddress` - The address to receive the flash loan fee (or zero address to
        /// burn)
        fn flash_fee_receiver(
            self: @ComponentState<TContractState>,
        ) -> ContractAddress {
            Zero::zero()
        }
    }

    /// ## ERC20 Flash Mint Implementation
    ///
    /// Implements the IERC3156FlashLender interface with flash mint capability.
    #[embeddable_as(ERC20FlashMintImpl)]
    impl ERC20FlashMint<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        impl FlashMintConfig: FlashMintConfigTrait<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of IERC3156FlashLender<ComponentState<TContractState>> {
        /// Returns the maximum amount of tokens available for flash loan.
        ///
        /// By default, this is the maximum value minus total supply, if `token` matches this
        /// contract's address.
        ///
        /// WARNING: If your implementation has an additional supply cap, this function will not
        /// correctly reflect the maximum that can be flash minted.
        fn max_flash_loan(self: @ComponentState<TContractState>, token: ContractAddress) -> u256 {
            let erc20_component = get_dep_component!(self, ERC20);
            let supply = erc20_component.total_supply();
            FlashMintConfig::max_flash_loan(self, token, supply)
        }

        /// Returns the fee to be charged for a given flash loan.
        ///
        /// Validates the token and dispatches to `FlashMintConfigTrait` for calculation.
        /// Override `FlashMintConfigTrait` to provide custom fees.
        fn flash_fee(
            self: @ComponentState<TContractState>, token: ContractAddress, amount: u256,
        ) -> u256 {
            // Returns the fee applied when doing flash loans.
            let this = get_contract_address();
            assert(token == this, Errors::UNSUPPORTED_TOKEN);
            FlashMintConfig::flash_fee(self, token, amount)
        }

        /// Executes a flash loan to `receiver` of `amount` tokens.
        ///
        /// - Mints the tokens to the receiver.
        /// - Invokes `on_flash_loan` on the receiver.
        /// - Ensures receiver has approved (amount + fee) tokens.
        /// - Burns the amount (+ possible burn of fee, or fee transferred to receiver as
        /// configured).
        ///
        /// NOTE: This function can reenter safely: minted tokens are always recovered
        /// and burned or the call reverts.
        ///
        /// # Arguments
        /// - `receiver` - The recipient of the flash loan (must implement on_flash_loan)
        /// - `token` - The token contract address requested (must be this contract)
        /// - `amount` - The number of tokens to loan
        /// - `data` - Arbitrary calldata passed to the receiver
        ///
        /// # Returns
        /// - `bool` - True if the flash loan was completed successfully
        fn flash_loan(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            token: ContractAddress,
            amount: u256,
            data: Span<felt252>,
        ) -> bool {
            // Check maximum flash loan.
            let max_loan = Self::max_flash_loan(@self, token);
            assert(amount <= max_loan, Errors::EXCEEDED_MAX_LOAN);

            // Calculate flash fee.
            let fee = Self::flash_fee(@self, token, amount);

            // Mint the loan amount to the receiver.
            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            erc20_component.mint(receiver, amount);

            // Call on_flash_loan on receiver
            let initiator = get_caller_address();
            let on_flash_ret = IERC3156FlashBorrowerDispatcher { contract_address: receiver }
                .on_flash_loan(initiator, token, amount, fee, data);
            assert(on_flash_ret == ON_FLASH_LOAN_RETURN, Errors::INVALID_RECEIVER);

            // Determine fee receiver.
            let fee_receiver = self.flash_fee_receiver();

            // `receiver` must approve contract for (amount + fee)
            erc20_component._spend_allowance(receiver, get_contract_address(), amount + fee);

            // Burn or transfer fee
            if fee == 0 || fee_receiver.is_zero() {
                erc20_component.burn(receiver, amount + fee);
            } else {
                erc20_component.burn(receiver, amount);
                erc20_component._transfer(receiver, fee_receiver, fee);
            }

            true
        }
    }
}

pub impl DefaultConfig<
    TContractState, +ERC20FlashMintComponent::HasComponent<TContractState>,
> of ERC20FlashMintComponent::FlashMintConfigTrait<TContractState> {}
