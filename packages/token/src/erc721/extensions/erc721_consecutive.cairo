// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0
// (token/src/erc721/extensions/erc721_consecutive.cairo)

/// # ERC721Consecutive Component
///
/// Implementation of the ERC-2309 "Consecutive Transfer Extension".
/// This allows batch minting of consecutive token IDs during construction.
#[starknet::component]
pub mod ERC721ConsecutiveComponent {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_utils::structs::bitmap::{BitMap, BitMapTrait};
    use openzeppelin_utils::structs::checkpoint::{Trace, TraceTrait};
    use starknet::ContractAddress;
    use crate::erc721::ERC721Component;
    use crate::erc721::ERC721Component::InternalImpl as ERC721InternalImpl;

    pub const DEFAULT_MAX_BATCH_SIZE: u64 = 5000;
    pub const DEFAULT_FIRST_CONSECUTIVE_ID: u64 = 0;

    /// Used to configure immutable settings for consecutive batch minting.
    pub trait ImmutableConfig {
        /// Maximum size of a batch of consecutive tokens.
        /// Designed to limit stress on off-chain indexing services that have to record one entry
        /// per token, and have protections against "unreasonably large" batches of tokens.
        ///
        /// NOTE: Overriding the default value of 5000 will not cause on-chain issues, but may
        /// result in the asset not being correctly supported by off-chain indexing services
        /// (including marketplaces).
        const MAX_BATCH_SIZE: u64;

        /// Used to offset the first token id in `next_consecutive_id`.
        const FIRST_CONSECUTIVE_ID: u64;
    }

    pub mod Errors {
        pub const FORBIDDEN_BATCH_MINT: felt252 = 'ERC721: forbidden batch mint';
        pub const EXCEEDED_MAX_BATCH_MINT: felt252 = 'ERC721: max batch exceeded';
        pub const FORBIDDEN_MINT: felt252 = 'ERC721: forbidden mint';
        pub const TOKEN_ID_OVERFLOW: felt252 = 'ERC721: token id overflow';
        pub const ADDRESS_OVERFLOW: felt252 = 'ERC721: address overflow';
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        ConsecutiveTransfer: ConsecutiveTransfer,
    }

    /// Emitted when a batch of consecutive tokens is transferred.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ConsecutiveTransfer {
        #[key]
        pub from_token_id: u256,
        pub to_token_id: u256,
        #[key]
        pub from_address: ContractAddress,
        #[key]
        pub to_address: ContractAddress,
    }

    #[storage]
    pub struct Storage {
        pub ERC721Consecutive_sequential_ownership: Trace,
        pub ERC721Consecutive_sequential_burn: BitMap,
    }

    /// Returns true if the current execution is in the constructor scope.
    pub fn is_constructor_scope() -> bool {
        starknet::get_execution_info().entry_point_selector == selector!("constructor")
    }

    fn fits_u64(value: u256) -> bool {
        let max_u64: u128 = 0xffff_ffff_ffff_ffff;
        value.high == 0 && value.low <= max_u64
    }

    fn u256_to_u64(value: u256) -> u64 {
        assert(fits_u64(value), Errors::TOKEN_ID_OVERFLOW);
        value.low.try_into().unwrap()
    }

    fn address_to_u256(value: ContractAddress) -> u256 {
        let felt: felt252 = value.into();
        felt.into()
    }

    fn u256_to_address(value: u256) -> ContractAddress {
        let felt: felt252 = value.try_into().expect(Errors::ADDRESS_OVERFLOW);
        felt.try_into().expect(Errors::ADDRESS_OVERFLOW)
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl Config: ImmutableConfig,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Returns the max batch size for consecutive mints.
        fn max_batch_size(self: @ComponentState<TContractState>) -> u64 {
            Config::MAX_BATCH_SIZE
        }

        /// Returns the first consecutive token id.
        fn first_consecutive_id(self: @ComponentState<TContractState>) -> u64 {
            Config::FIRST_CONSECUTIVE_ID
        }

        /// Returns the next token id to mint using `mint_consecutive`.
        fn next_consecutive_id(self: @ComponentState<TContractState>) -> u64 {
            let (exists, last_id, _) = self
                .ERC721Consecutive_sequential_ownership
                .deref()
                .latest_checkpoint();
            if exists {
                last_id + 1
            } else {
                self.first_consecutive_id()
            }
        }

        /// Returns whether the consecutive token at `token_id` has been burned.
        fn is_sequentially_burned(self: @ComponentState<TContractState>, token_id: u256) -> bool {
            self.ERC721Consecutive_sequential_burn.deref().get(token_id)
        }

        /// Returns the owner of the consecutive token at `token_id` from sequential ownership.
        fn sequential_owner_of(
            self: @ComponentState<TContractState>, token_id: u256,
        ) -> ContractAddress {
            let token_id_u64 = u256_to_u64(token_id);
            let packed_owner = self
                .ERC721Consecutive_sequential_ownership
                .deref()
                .lower_lookup(token_id_u64);
            u256_to_address(packed_owner)
        }

        /// Mints a batch of consecutive tokens of length `batch_size` for `to`.
        ///
        /// Returns the token id of the first token minted in the batch.
        /// If `batch_size` is 0, returns the number of the next consecutive id to mint.
        ///
        /// Requirements:
        /// - `batch_size` must not be greater than `max_batch_size`.
        /// - The function must be called during the contract's constructor (directly or
        /// indirectly).
        ///
        /// CAUTION: Does not emit individual `Transfer` events for each token.
        /// This is compliant with ERC-721 as long as it is done within the constructor,
        /// which is enforced by this function.
        ///
        /// CAUTION: Does NOT invoke `onERC721Received` on the receiver.
        ///
        /// Emits a `ConsecutiveTransfer` event as defined by IERC2309.
        fn mint_consecutive(
            ref self: ComponentState<TContractState>, to: ContractAddress, batch_size: u64,
        ) -> u64 {
            let next = self.next_consecutive_id();

            if batch_size > 0 {
                assert(is_constructor_scope(), Errors::FORBIDDEN_BATCH_MINT);
                assert(!to.is_zero(), ERC721Component::Errors::INVALID_RECEIVER);

                let max_batch_size = Self::max_batch_size(@self);
                assert(batch_size <= max_batch_size, Errors::EXCEEDED_MAX_BATCH_MINT);

                let last: u64 = next + batch_size - 1;

                let mut ownership = self.ERC721Consecutive_sequential_ownership.deref();
                ownership.push(last, address_to_u256(to));

                let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
                let batch_size_u128: u128 = batch_size.into();
                erc721_component.increase_balance(to, batch_size_u128);

                self
                    .emit(
                        ConsecutiveTransfer {
                            from_token_id: next.into(),
                            to_token_id: last.into(),
                            from_address: Zero::zero(),
                            to_address: to,
                        },
                    );
            }

            next
        }

        /// ERC721 update wrapper that enforces consecutive minting rules.
        ///
        /// WARNING: Using {ERC721Consecutive} prevents minting during construction in favor of
        /// `mint_consecutive`. After construction, `mint_consecutive` is no longer available and
        /// minting through `update` becomes available.
        fn update(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) -> ContractAddress {
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            let previous_owner = erc721_component.update(to, token_id, auth);

            // Only mint after construction
            if previous_owner.is_zero() {
                assert(!is_constructor_scope(), Errors::FORBIDDEN_MINT);
            }

            // Update sequential burn bitmap
            if to.is_zero()
                && token_id < self.next_consecutive_id().into()
                && token_id >= self.first_consecutive_id().into()
                && !self.is_sequentially_burned(token_id) {
                self.ERC721Consecutive_sequential_burn.deref().set(token_id);
            }

            previous_owner
        }
    }
}

/// Implementation of the default ERC721ConsecutiveComponent configuration.
pub impl DefaultConfig of ERC721ConsecutiveComponent::ImmutableConfig {
    const MAX_BATCH_SIZE: u64 = ERC721ConsecutiveComponent::DEFAULT_MAX_BATCH_SIZE;
    const FIRST_CONSECUTIVE_ID: u64 = ERC721ConsecutiveComponent::DEFAULT_FIRST_CONSECUTIVE_ID;
}
