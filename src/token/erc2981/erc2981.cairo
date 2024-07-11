// SPDX-License-Identifier: MIT

/// #ERC2981 Component
/// 
/// The ERC2981 compononet provides an implementation of the IERC2981 interface.
#[starknet::component]
pub mod ERC2981Component {
    use core::num::traits::Zero;

    use openzeppelin::access::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc2981::interface::{IERC2981, IERC2981Setup, IERC2981_ID};

    use openzeppelin::token::erc2981::{FeesRatio, FeesImpl, FeesRatioDefault};

    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        default_receiver: ContractAddress,
        default_fees: FeesRatio,
        token_receiver: LegacyMap<u256, ContractAddress>,
        token_fees: LegacyMap<u256, FeesRatio>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenRoyaltyUpdated: TokenRoyaltyUpdated,
        DefaultRoyaltyUpdated: DefaultRoyaltyUpdated,
    }

    /// Emitted when token id `token_id` royalty is updated to fees ratio `fees_ratio`
    /// and receiver `receiver`. 
    #[derive(Drop, starknet::Event)]
    pub struct TokenRoyaltyUpdated {
        #[key]
        token_id: u256,
        fees_ratio: FeesRatio,
        receiver: ContractAddress,
    }

    /// Emitted when default royalty is updated to fees ratio `fees_ratio` and receiver `receiver`.
    #[derive(Drop, starknet::Event)]
    pub struct DefaultRoyaltyUpdated {
        fees_ratio: FeesRatio,
        receiver: ContractAddress,
    }

    pub mod Errors {
        pub const NOT_VALID_FEES_RATIO: felt252 = 'Fees ratio is not valid';
    }

    //
    // External
    //

    #[embeddable_as(ERC2981Impl)]
    impl ERC2981<
        TContractState, +HasComponent<TContractState>
    > of IERC2981<ComponentState<TContractState>> {
        /// Returns the receiver address and amount to send for royalty
        /// for token id `token_id` and sale price `sale_price`
        fn royalty_info(
            self: @ComponentState<TContractState>, token_id: u256, sale_price: u256
        ) -> (ContractAddress, u256) {
            let receiver = self.token_receiver.read(token_id);
            if !receiver.is_zero() {
                let fees_ratio = self.token_fees.read(token_id);
                (receiver, fees_ratio.compute_amount(sale_price))
            } else {
                let fees_ratio = self.default_fees.read();
                (self.default_receiver.read(), fees_ratio.compute_amount(sale_price))
            }
        }
    }

    #[embeddable_as(ERC2981SetupImpl)]
    impl ERC2981Setup<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
    > of IERC2981Setup<ComponentState<TContractState>> {
        /// Returns the default royalty.
        fn default_royalty(self: @ComponentState<TContractState>) -> (ContractAddress, FeesRatio) {
            (self.default_receiver.read(), self.default_fees.read())
        }

        /// Set the default royalty.
        /// 
        /// Requirements:
        /// - The caller is the owner.
        /// 
        /// Emits a `DefaultRoyaltyUpdated` even.
        fn set_default_royalty(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            fees_ratio: FeesRatio
        ) {
            let ownable_component = get_dep_component!(@self, Ownable);
            ownable_component.assert_only_owner();
            assert(fees_ratio.is_valid(), Errors::NOT_VALID_FEES_RATIO);

            self.default_receiver.write(receiver);
            self.default_fees.write(fees_ratio);
            self.emit(DefaultRoyaltyUpdated { fees_ratio: fees_ratio, receiver: receiver, });
        }

        /// Returns the royalty for given token id `token_id`
        fn token_royalty(
            self: @ComponentState<TContractState>, token_id: u256
        ) -> (ContractAddress, FeesRatio) {
            let fees_ratio: FeesRatio = self.token_fees.read(token_id);
            if !fees_ratio.denominator.is_zero() {
                (self.token_receiver.read(token_id), fees_ratio)
            } else {
                (self.token_receiver.read(token_id), Default::default())
            }
        }

        /// Set the royalty for given token id `token_id`
        /// 
        /// Requirements:
        /// - The caller is the owner
        /// 
        /// Emits a `TokenRoyaltyUpdated` event.
        fn set_token_royalty(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            receiver: ContractAddress,
            fees_ratio: FeesRatio
        ) {
            let ownable_component = get_dep_component!(@self, Ownable);
            ownable_component.assert_only_owner();
            assert(fees_ratio.is_valid(), Errors::NOT_VALID_FEES_RATIO);

            self.token_receiver.write(token_id, receiver);

            self.token_fees.write(token_id, fees_ratio);
            self
                .emit(
                    TokenRoyaltyUpdated {
                        token_id: token_id, fees_ratio: fees_ratio, receiver: receiver,
                    }
                );
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
            default_fees: FeesRatio
        ) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC2981_ID);

            self.default_receiver.write(default_receiver);
            self.default_fees.write(default_fees);
        }
    }
}
