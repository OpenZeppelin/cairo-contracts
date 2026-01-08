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
    use openzeppelin_utils::math;
    use openzeppelin_utils::structs::checkpoint::{Trace, TraceTrait};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageAsPath, StorageMapReadAccess, StorageMapWriteAccess, StoragePath,
        StoragePointerReadAccess, StoragePointerWriteAccess, VecTrait,
    };
    use crate::erc721::ERC721Component;
    use crate::erc721::ERC721Component::InternalImpl as ERC721InternalImpl;

    pub const DEFAULT_MAX_BATCH_SIZE: u256 = 5000;
    pub const DEFAULT_FIRST_CONSECUTIVE_ID: u256 = 0;

    pub trait ImmutableConfig {
        const MAX_BATCH_SIZE: u256;
        const FIRST_CONSECUTIVE_ID: u256;
    }

    pub mod Errors {
        pub const FORBIDDEN_BATCH_MINT: felt252 = 'ERC721Consecutive: forbidden batch mint';
        pub const EXCEEDED_MAX_BATCH_MINT: felt252 = 'ERC721Consecutive: max batch exceeded';
        pub const FORBIDDEN_MINT: felt252 = 'ERC721Consecutive: forbidden mint';
        pub const FORBIDDEN_BATCH_BURN: felt252 = 'ERC721Consecutive: forbidden batch burn';
        pub const TOKEN_ID_OVERFLOW: felt252 = 'ERC721Consecutive: token id overflow';
        pub const ADDRESS_OVERFLOW: felt252 = 'ERC721Consecutive: address overflow';
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
        pub ERC721Consecutive_sequential_burn: Map<u256, bool>,
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

    fn u64_to_u256(value: u64) -> u256 {
        let low: u128 = value.into();
        u256 { low, high: 0 }
    }

    fn address_to_u256(value: ContractAddress) -> u256 {
        let felt: felt252 = value.into();
        felt.into()
    }

    fn u256_to_address(value: u256) -> ContractAddress {
        let felt: felt252 = value.try_into().expect(Errors::ADDRESS_OVERFLOW);
        felt.try_into().unwrap()
    }

    fn lower_lookup(trace: StoragePath<Trace>, token_id: u64) -> u256 {
        let checkpoints = trace.checkpoints.as_path();
        let len = checkpoints.len();

        let mut low = 0;
        let mut high = len;

        #[allow(inefficient_while_comp)]
        while low < high {
            let mid = math::average(low, high);
            let checkpoint = checkpoints[mid].read();
            if token_id <= checkpoint.key {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        if low == len {
            0
        } else {
            checkpoints[low].read().value
        }
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
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Returns the max batch size for consecutive mints.
        fn max_batch_size(self: @ComponentState<TContractState>) -> u256 {
            Config::MAX_BATCH_SIZE
        }

        /// Returns the first consecutive token id.
        fn first_consecutive_id(self: @ComponentState<TContractState>) -> u256 {
            Config::FIRST_CONSECUTIVE_ID
        }

        /// Returns the next token id to mint using `mint_consecutive`.
        fn _next_consecutive_id(self: @ComponentState<TContractState>) -> u256 {
            let (exists, last_id, _) =
                self.ERC721Consecutive_sequential_ownership.deref().latest_checkpoint();
            if exists {
                let max_u64: u128 = 0xffff_ffff_ffff_ffff;
                let next_u128: u128 = last_id.into() + 1_u128;
                assert(next_u128 <= max_u64, Errors::TOKEN_ID_OVERFLOW);
                u64_to_u256(next_u128.try_into().unwrap())
            } else {
                Self::first_consecutive_id(self)
            }
        }

        /// Returns the owner of `token_id`, checking sequential ownership when needed.
        fn _owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            let erc721_component = get_dep_component!(self, ERC721);
            let owner = erc721_component._owner_of(token_id);

            if owner.is_non_zero()
                || token_id < Self::first_consecutive_id(self)
                || !fits_u64(token_id)
            {
                return owner;
            }

            if self.ERC721Consecutive_sequential_burn.read(token_id) {
                Zero::zero()
            } else {
                let token_id_u64 = u256_to_u64(token_id);
                let packed_owner = lower_lookup(
                    self.ERC721Consecutive_sequential_ownership.deref(),
                    token_id_u64,
                );
                u256_to_address(packed_owner)
            }
        }

        /// Batch mint consecutive tokens for `to`.
        fn mint_consecutive(
            ref self: ComponentState<TContractState>, to: ContractAddress, batch_size: u256,
        ) -> u256 {
            let next = self._next_consecutive_id();

            if batch_size > 0 {
                assert(is_constructor_scope(), Errors::FORBIDDEN_BATCH_MINT);
                assert(!to.is_zero(), ERC721Component::Errors::INVALID_RECEIVER);

                let max_batch_size = Self::max_batch_size(@self);
                assert(batch_size <= max_batch_size, Errors::EXCEEDED_MAX_BATCH_MINT);

                let next_u64 = u256_to_u64(next);
                let batch_size_u64 = u256_to_u64(batch_size);
                let last_u128: u128 = next_u64.into() + batch_size_u64.into() - 1_u128;
                let max_u64: u128 = 0xffff_ffff_ffff_ffff;
                assert(last_u128 <= max_u64, Errors::TOKEN_ID_OVERFLOW);
                let last_u64: u64 = last_u128.try_into().unwrap();
                let last = u64_to_u256(last_u64);

                let mut ownership = self.ERC721Consecutive_sequential_ownership.deref();
                ownership.push(last_u64, address_to_u256(to));

                let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
                let current_balance = erc721_component.ERC721_balances.read(to);
                erc721_component.ERC721_balances.write(to, current_balance + batch_size);

                self.emit(
                    ConsecutiveTransfer {
                        from_token_id: next,
                        to_token_id: last,
                        from_address: Zero::zero(),
                        to_address: to,
                    },
                );
            }

            next
        }

        /// ERC721 update wrapper that enforces consecutive minting rules.
        fn update(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) -> ContractAddress {
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            let previous_owner = erc721_component.update(to, token_id, auth);

            if previous_owner.is_zero() {
                assert(!is_constructor_scope(), Errors::FORBIDDEN_MINT);
            }

            if to.is_zero()
                && token_id < self._next_consecutive_id()
                && !self.ERC721Consecutive_sequential_burn.read(token_id)
            {
                self.ERC721Consecutive_sequential_burn.write(token_id, true);
            }

            previous_owner
        }
    }
}

/// Implementation of the default ERC721ConsecutiveComponent configuration.
pub impl DefaultConfig of ERC721ConsecutiveComponent::ImmutableConfig {
    const MAX_BATCH_SIZE: u256 = ERC721ConsecutiveComponent::DEFAULT_MAX_BATCH_SIZE;
    const FIRST_CONSECUTIVE_ID: u256 = ERC721ConsecutiveComponent::DEFAULT_FIRST_CONSECUTIVE_ID;
}
