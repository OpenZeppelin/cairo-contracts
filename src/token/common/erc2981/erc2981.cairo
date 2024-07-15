// SPDX-License-Identifier: MIT

/// #ERC2981 Component
/// 
/// The ERC2981 compononet provides an implementation of the IERC2981 interface.
#[starknet::component]
pub mod ERC2981Component {
    use core::num::traits::Zero;

    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::common::erc2981::interface::{IERC2981, IERC2981_ID};

    use starknet::ContractAddress;

    #[derive(Serde, Drop, PartialEq, starknet::Store)]
    struct RoyaltyInfo {
        pub receiver: ContractAddress,
        pub royalty_fraction: u256,
    }

    #[storage]
    struct Storage {
        default_royalty_info: RoyaltyInfo,
        token_royalty_info: LegacyMap<u256, RoyaltyInfo>,
    }

    //
    // External
    //
    #[embeddable_as(ERC2981Impl)]
    impl ERC2981<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC2981<ComponentState<TContractState>> {
        /// Returns the receiver address and amount to send for royalty
        /// for token id `token_id` and sale price `sale_price`
        fn royalty_info(
            self: @ComponentState<TContractState>, token_id: u256, sale_price: u256
        ) -> (ContractAddress, u256) {
            let royalty_info: RoyaltyInfo = self.token_royalty_info.read(token_id);
            let mut royalty_receiver = royalty_info.receiver;
            let mut royalty_fraction = royalty_info.royalty_fraction;

            if royalty_receiver.is_zero() {
                let default_royalty_info: RoyaltyInfo = self.default_royalty_info.read();
                royalty_receiver = default_royalty_info.receiver;
                royalty_fraction = default_royalty_info.royalty_fraction;
            }

            let royalty_amount: u256 = (sale_price * royalty_fraction) / self._fee_denominator();

            (royalty_receiver, royalty_amount)
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
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by setting default royalty.
        fn initializer(
            ref self: ComponentState<TContractState>,
            default_receiver: ContractAddress,
            default_royalty_fraction: u256
        ) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC2981_ID);

            self._set_default_royalty(default_receiver, default_royalty_fraction)
        }


        /// The denominator with which to interpret the fee set in {_set_token_royalty} and {_set_default_royalty} as a
        /// fraction of the sale price. 
        /// Defaults to 10000 so fees are expressed in basis points
        fn _fee_denominator(self: @ComponentState<TContractState>) -> u256 {
            10000
        }

        /// Returns the royalty information that all ids in this contract will default to.
        fn _default_royalty(
            self: @ComponentState<TContractState>
        ) -> (ContractAddress, u256, u256) {
            let royalty_info: RoyaltyInfo = self.default_royalty_info.read();
            (royalty_info.receiver, royalty_info.royalty_fraction, self._fee_denominator())
        }

        /// Sets the royalty information that all ids in this contract will default to.
        ///
        /// Requirements:
        ///
        /// - `receiver` cannot be the zero address.
        /// - `fee_numerator` cannot be greater than the fee denominator.
        fn _set_default_royalty(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            fee_numerator: u256,
        ) {
            let denominator = self._fee_denominator();
            assert!(fee_numerator <= denominator, "Invalid default royalty");
            assert!(!receiver.is_zero(), "Invalid default royalty receiver");
            self
                .default_royalty_info
                .write(RoyaltyInfo { receiver, royalty_fraction: fee_numerator })
        }


        /// Sets the royalty information for a specific token id, overriding the global default.
        ///
        /// Requirements:
        ///
        /// - `receiver` cannot be the zero address.
        /// - `fee_numerator` cannot be greater than the fee denominator.
        fn _set_token_royalty(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            receiver: ContractAddress,
            fee_numerator: u256
        ) {
            let denominator = self._fee_denominator();
            assert!(fee_numerator <= denominator, "Invalid token royalty");
            assert!(!receiver.is_zero(), "Invalid token royalty receiver");

            self
                .token_royalty_info
                .write(token_id, RoyaltyInfo { receiver, royalty_fraction: fee_numerator },)
        }

        /// Returns the royalty information that all ids in this contract will default to.
        fn _token_royalty(
            self: @ComponentState<TContractState>, token_id: u256
        ) -> (ContractAddress, u256, u256) {
            let royalty_info: RoyaltyInfo = self.token_royalty_info.read(token_id);
            let mut receiver = royalty_info.receiver;
            let mut royalty_fraction = royalty_info.royalty_fraction;

            if receiver.is_zero() {
                let default_royalty_info: RoyaltyInfo = self.default_royalty_info.read();
                receiver = default_royalty_info.receiver;
                royalty_fraction = default_royalty_info.royalty_fraction;
            };
            (receiver, royalty_fraction, self._fee_denominator())
        }


        /// Resets royalty information for the token id back to the global default.
        fn _reset_token_royalty(ref self: ComponentState<TContractState>, token_id: u256) {
            self
                .token_royalty_info
                .write(token_id, RoyaltyInfo { receiver: Zero::zero(), royalty_fraction: 0 },)
        }
    }
}
