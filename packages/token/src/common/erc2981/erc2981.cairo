// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (token/common/erc2981/erc2981.cairo)

/// # ERC2981 Component
///
/// Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment
/// information.
///
/// Royalty information can be specified globally for all token ids via `set_default_royalty`,
/// and/or individually for specific token ids via `set_token_royalty`. The latter takes precedence
/// over the first.
///
/// Royalty is specified as a fraction of sale price. The denominator is set by the contract by
/// using the Immutable Component Config pattern.
/// See https://community.starknet.io/t/immutable-component-config/114434.
///
/// IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its
/// payment. See https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the
/// ERC. Marketplaces are expected to voluntarily pay royalties together with sales.
#[starknet::component]
pub mod ERC2981Component {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::common::erc2981::interface::{IERC2981, IERC2981_ID};
    use starknet::ContractAddress;
    use starknet::storage::Map;

    // This default denominator is only used when the DefaultConfig
    // is in scope in the implementing contract.
    pub const DEFAULT_FEE_DENOMINATOR: u128 = 10_000;

    #[derive(Serde, Drop, starknet::Store)]
    struct RoyaltyInfo {
        pub receiver: ContractAddress,
        pub royalty_fraction: u128,
    }

    #[storage]
    struct Storage {
        default_royalty_info: RoyaltyInfo,
        token_royalty_info: Map<u256, RoyaltyInfo>,
    }

    mod Errors {
        pub const INVALID_ROYALTY: felt252 = 'ERC2981: invalid royalty';
        pub const INVALID_ROYALTY_RECEIVER: felt252 = 'ERC2981: invalid receiver';
    }

    /// Constants expected to be defined at the contract level used to configure the component
    /// behaviour.
    ///
    /// - `FEE_DENOMINATOR`: The denominator with which to interpret the fee set in
    ///   `set_token_royalty` and `set_default_royalty` as a fraction of the sale price.
    pub trait ImmutableConfig {
        const FEE_DENOMINATOR: u128;
    }

    //
    // External
    //

    #[embeddable_as(ERC2981Impl)]
    impl ERC2981<
        TContractState,
        +HasComponent<TContractState>,
        impl Immutable: ImmutableConfig,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC2981<ComponentState<TContractState>> {
        /// Returns how much royalty is owed and to whom, based on a sale price that may be
        /// denominated in any unit of exchange. The royalty amount is denominated and should be
        /// paid in that same unit of exchange.
        ///
        /// The returned tuple contains:
        ///
        /// - `t.0`: The receiver of the royalty payment.
        /// - `t.1`: The amount of royalty payment.
        fn royalty_info(
            self: @ComponentState<TContractState>, token_id: u256, sale_price: u256
        ) -> (ContractAddress, u256) {
            let token_royalty_info = self.token_royalty_info.read(token_id);

            // If the token has no specific royalty info, use the default.
            let royalty_info = if token_royalty_info.receiver.is_zero() {
                self.default_royalty_info.read()
            } else {
                token_royalty_info
            };

            let royalty_amount = sale_price
                * royalty_info.royalty_fraction.into()
                / Immutable::FEE_DENOMINATOR.into();

            (royalty_info.receiver, royalty_amount)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Immutable: ImmutableConfig,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by setting the default royalty.
        fn initializer(
            ref self: ComponentState<TContractState>,
            default_receiver: ContractAddress,
            default_royalty_fraction: u128
        ) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC2981_ID);

            self.set_default_royalty(default_receiver, default_royalty_fraction)
        }

        /// Returns the royalty information that all ids in this contract will default to.
        ///
        /// The returned tuple contains:
        ///
        /// - `t.0`: The receiver of the royalty payment.
        /// - `t.1`: The numerator of the royalty fraction.
        /// - `t.2`: The denominator of the royalty fraction.
        fn default_royalty(self: @ComponentState<TContractState>) -> (ContractAddress, u128, u128) {
            let royalty_info = self.default_royalty_info.read();
            (royalty_info.receiver, royalty_info.royalty_fraction, Immutable::FEE_DENOMINATOR)
        }

        /// Sets the royalty information that all ids in this contract will default to.
        ///
        /// Requirements:
        ///
        /// - `receiver` cannot be the zero address.
        /// - `fee_numerator` cannot be greater than the fee denominator.
        fn set_default_royalty(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            fee_numerator: u128,
        ) {
            let fee_denominator = Immutable::FEE_DENOMINATOR;
            assert(fee_numerator <= fee_denominator, Errors::INVALID_ROYALTY);
            assert(receiver.is_non_zero(), Errors::INVALID_ROYALTY_RECEIVER);
            self
                .default_royalty_info
                .write(RoyaltyInfo { receiver, royalty_fraction: fee_numerator })
        }

        /// Removes default royalty information.
        fn delete_default_royalty(ref self: ComponentState<TContractState>) {
            self
                .default_royalty_info
                .write(RoyaltyInfo { receiver: Zero::zero(), royalty_fraction: 0 })
        }

        /// Returns the royalty information specific to a token.
        /// If no specific royalty information is set for the token, the default is returned.
        ///
        /// The returned tuple contains:
        ///
        /// - `t.0`: The receiver of the royalty payment.
        /// - `t.1`: The numerator of the royalty fraction.
        /// - `t.2`: The denominator of the royalty fraction.
        fn token_royalty(
            self: @ComponentState<TContractState>, token_id: u256
        ) -> (ContractAddress, u128, u128) {
            let token_royalty_info = self.token_royalty_info.read(token_id);

            // If the token has no specific royalty info, use the default.
            let royalty_info = if token_royalty_info.receiver.is_zero() {
                self.default_royalty_info.read()
            } else {
                token_royalty_info
            };

            (royalty_info.receiver, royalty_info.royalty_fraction, Immutable::FEE_DENOMINATOR)
        }

        /// Sets the royalty information for a specific token id, overriding the global default.
        ///
        /// Requirements:
        ///
        /// - `receiver` cannot be the zero address.
        /// - `fee_numerator` cannot be greater than the fee denominator.
        fn set_token_royalty(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            receiver: ContractAddress,
            fee_numerator: u128
        ) {
            let fee_denominator = Immutable::FEE_DENOMINATOR;
            assert(fee_numerator <= fee_denominator, Errors::INVALID_ROYALTY);
            assert(!receiver.is_zero(), Errors::INVALID_ROYALTY_RECEIVER);

            self
                .token_royalty_info
                .write(token_id, RoyaltyInfo { receiver, royalty_fraction: fee_numerator },)
        }

        /// Resets royalty information for the token id back to unset.
        fn reset_token_royalty(ref self: ComponentState<TContractState>, token_id: u256) {
            self
                .token_royalty_info
                .write(token_id, RoyaltyInfo { receiver: Zero::zero(), royalty_fraction: 0 },)
        }
    }
}

/// Implementation of the default ERC2981Component ImmutableConfig.
/// See https://community.starknet.io/t/immutable-component-config/114434#p-2357364-defaultconfig-4
///
/// The default fee denominator is set to DEFAULT_FEE_DENOMINATOR.
pub impl DefaultConfig of ERC2981Component::ImmutableConfig {
    const FEE_DENOMINATOR: u128 = ERC2981Component::DEFAULT_FEE_DENOMINATOR;
}
