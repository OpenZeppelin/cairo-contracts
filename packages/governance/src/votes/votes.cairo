// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (governance/votes/votes.cairo)

use starknet::ContractAddress;


/// # Votes Component
///
/// The Votes component provides a flexible system for tracking and delegating voting power.
/// that is currently implemented for ERC20 and ERC721 tokens. An account can delegate
/// their voting power to a representative, that will pool delegated voting units from different
/// delegators and can then use it to vote in decisions. Voting power must be delegated to be counted,
/// and an account must delegate to itself if it wishes to vote directly without a trusted
/// representative.
///
/// When integrating the Votes component, the ´VotingUnitsTrait´ must be implemented to get the voting
/// units for a given account as a function of the implementing contract. For simplicity, this module
/// already provides two implementations for ERC20 and ERC721 tokens, which will work out of the box
/// if the respective components are integrated.
///
/// NOTE: ERC20 and ERC721 tokens implementing this component must call ´transfer_voting_units´
/// whenever a transfer, mint, or burn operation is performed. Hooks can be leveraged for this purpose,
/// as shown in the following ERC20 example:
///
/// ```cairo
/// #[starknet::contract]
/// pub mod ERC20VotesContract {
///     use openzeppelin_governance::votes::VotesComponent;
///     use openzeppelin_token::erc20::ERC20Component;
///     use openzeppelin_utils::cryptography::nonces::NoncesComponent;
///     use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
///     use starknet::ContractAddress;
///
///     component!(path: VotesComponent, storage: erc20_votes, event: ERC20VotesEvent);
///     component!(path: ERC20Component, storage: erc20, event: ERC20Event);
///     component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);
///
///     #[abi(embed_v0)]
///     impl VotesImpl = VotesComponent::VotesImpl<ContractState>;
///     impl VotesInternalImpl = VotesComponent::InternalImpl<ContractState>;
///
///     #[abi(embed_v0)]
///     impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
///     impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
///
///     #[abi(embed_v0)]
///     impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;
///
///     #[storage]
///     pub struct Storage {
///         #[substorage(v0)]
///         pub erc20_votes: VotesComponent::Storage,
///         #[substorage(v0)]
///         pub erc20: ERC20Component::Storage,
///         #[substorage(v0)]
///         pub nonces: NoncesComponent::Storage
///     }
///
///     #[event]
///     #[derive(Drop, starknet::Event)]
///     enum Event {
///         #[flat]
///         ERC20VotesEvent: VotesComponent::Event,
///         #[flat]
///         ERC20Event: ERC20Component::Event,
///         #[flat]
///         NoncesEvent: NoncesComponent::Event
///     }
///
///     pub impl SNIP12MetadataImpl of SNIP12Metadata {
///         fn name() -> felt252 {
///             'DAPP_NAME'
///         }
///         fn version() -> felt252 {
///             'DAPP_VERSION'
///         }
///     }
///
///     impl ERC20VotesHooksImpl<
///         TContractState,
///         impl Votes: VotesComponent::HasComponent<TContractState>,
///         impl HasComponent: ERC20Component::HasComponent<TContractState>,
///         +NoncesComponent::HasComponent<TContractState>,
///         +Drop<TContractState>
///     > of ERC20Component::ERC20HooksTrait<TContractState> {
///         fn after_update(
///             ref self: ERC20Component::ComponentState<TContractState>,
///             from: ContractAddress,
///             recipient: ContractAddress,
///             amount: u256
///         ) {
///             let mut votes_component = get_dep_component_mut!(ref self, Votes);
///             votes_component.transfer_voting_units(from, recipient, amount);
///         }
///     }
///
///     #[constructor]
///     fn constructor(ref self: ContractState) {
///         self.erc20.initializer("MyToken", "MTK");
///     }
/// }
#[starknet::component]
pub mod VotesComponent {
    use core::num::traits::Zero;
    use crate::votes::interface::IVotes;
    use crate::votes::delegation::Delegation;
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::ERC20Component;
    use openzeppelin_token::erc20::interface::IERC20;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::interface::IERC721;
    use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12Metadata};
    use openzeppelin_utils::nonces::NoncesComponent::InternalTrait as NoncesInternalTrait;
    use openzeppelin_utils::nonces::NoncesComponent;
    use openzeppelin_utils::structs::checkpoint::{Trace, TraceTrait};
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};
    use super::{VotingUnitsTrait, ContractAddress};

    #[storage]
    pub struct Storage {
        pub Votes_delegatee: Map<ContractAddress, ContractAddress>,
        pub Votes_delegate_checkpoints: Map<ContractAddress, Trace>,
        pub Votes_total_checkpoints: Trace,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        DelegateChanged: DelegateChanged,
        DelegateVotesChanged: DelegateVotesChanged,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    /// Emitted when `delegator` delegates their votes from `from_delegate` to `to_delegate`.
    pub struct DelegateChanged {
        #[key]
        pub delegator: ContractAddress,
        #[key]
        pub from_delegate: ContractAddress,
        #[key]
        pub to_delegate: ContractAddress
    }

    /// Emitted when `delegate` votes are updated from `previous_votes` to `new_votes`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct DelegateVotesChanged {
        #[key]
        pub delegate: ContractAddress,
        pub previous_votes: u256,
        pub new_votes: u256
    }

    pub mod Errors {
        pub const FUTURE_LOOKUP: felt252 = 'Votes: future Lookup';
        pub const EXPIRED_SIGNATURE: felt252 = 'Votes: expired signature';
        pub const INVALID_SIGNATURE: felt252 = 'Votes: invalid signature';
    }

    #[embeddable_as(VotesImpl)]
    impl Votes<
        TContractState,
        +HasComponent<TContractState>,
        impl Nonces: NoncesComponent::HasComponent<TContractState>,
        +VotingUnitsTrait<ComponentState<TContractState>>,
        +SNIP12Metadata,
        +Drop<TContractState>
    > of IVotes<ComponentState<TContractState>> {
        /// Returns the current amount of votes that `account` has.
        fn get_votes(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.Votes_delegate_checkpoints.entry(account).latest()
        }

        /// Returns the amount of votes that `account` had at a specific moment in the past.
        ///
        /// Requirements:
        ///
        /// - `timepoint` must be in the past.
        fn get_past_votes(
            self: @ComponentState<TContractState>, account: ContractAddress, timepoint: u64
        ) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);
            self.Votes_delegate_checkpoints.entry(account).upper_lookup_recent(timepoint)
        }

        /// Returns the total supply of votes available at a specific moment in the past.
        ///
        /// Requirements:
        ///
        /// - `timepoint` must be in the past.
        fn get_past_total_supply(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);
            self.Votes_total_checkpoints.deref().upper_lookup_recent(timepoint)
        }

        /// Returns the delegate that `account` has chosen.
        fn delegates(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> ContractAddress {
            self.Votes_delegatee.read(account)
        }

        /// Delegates votes from the sender to `delegatee`.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
        fn delegate(ref self: ComponentState<TContractState>, delegatee: ContractAddress) {
            let sender = starknet::get_caller_address();
            self._delegate(sender, delegatee);
        }

        /// Delegates votes from the sender to `delegatee` through a SNIP12 message signature
        /// validation.
        ///
        /// Requirements:
        ///
        /// - `expiry` must not be in the past.
        /// - `nonce` must match the account's current nonce.
        /// - `delegator` must implement `SRC6::is_valid_signature`.
        /// - `signature` should be valid for the message hash.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
        fn delegate_by_sig(
            ref self: ComponentState<TContractState>,
            delegator: ContractAddress,
            delegatee: ContractAddress,
            nonce: felt252,
            expiry: u64,
            signature: Array<felt252>
        ) {
            assert(starknet::get_block_timestamp() <= expiry, Errors::EXPIRED_SIGNATURE);

            // Check and increase nonce.
            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component.use_checked_nonce(delegator, nonce);

            // Build hash for calling `is_valid_signature`.
            let delegation = Delegation { delegatee, nonce, expiry };
            let hash = delegation.get_message_hash(delegator);

            let is_valid_signature_felt = ISRC6Dispatcher { contract_address: delegator }
                .is_valid_signature(hash, signature);

            // Check either 'VALID' or true for backwards compatibility.
            let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
                || is_valid_signature_felt == 1;

            assert(is_valid_signature, Errors::INVALID_SIGNATURE);

            // Delegate votes.
            self._delegate(delegator, delegatee);
        }
    }

    //
    // Internal
    //

    impl ERC721VotesImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +Drop<TContractState>
    > of VotingUnitsTrait<ComponentState<TContractState>> {
        /// Returns the number of voting units for a given account.
        ///
        /// This implementation is specific to ERC721 tokens, where each token
        /// represents one voting unit. The function returns the balance of
        /// ERC721 tokens for the specified account.
        fn get_voting_units(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            let erc721_component = get_dep_component!(self, ERC721);
            erc721_component.balance_of(account).into()
        }
    }

    impl ERC20VotesImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>
    > of VotingUnitsTrait<ComponentState<TContractState>> {
        /// Returns the number of voting units for a given account.
        ///
        /// This implementation is specific to ERC20 tokens, where the balance
        /// of tokens directly represents the number of voting units.
        fn get_voting_units(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            let erc20_component = get_dep_component!(self, ERC20);
            erc20_component.balance_of(account)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +VotingUnitsTrait<ComponentState<TContractState>>,
        +NoncesComponent::HasComponent<TContractState>,
        +SNIP12Metadata,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Delegates all of `account`'s voting units to `delegatee`.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
        fn _delegate(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            delegatee: ContractAddress
        ) {
            let from_delegate = self.delegates(account);
            self.Votes_delegatee.write(account, delegatee);
            self
                .emit(
                    DelegateChanged { delegator: account, from_delegate, to_delegate: delegatee }
                );
            self
                .move_delegate_votes(
                    from_delegate, delegatee, self.get_voting_units(account)
                );
        }

        /// Moves delegated votes from one delegate to another.
        ///
        /// May emit one or two `DelegateVotesChanged` events.
        fn move_delegate_votes(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            let block_timestamp = starknet::get_block_timestamp();
            if from != to && amount > 0 {
                if from.is_non_zero() {
                    let mut trace = self.Votes_delegate_checkpoints.entry(from);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.into().latest() - amount);
                    self.emit(DelegateVotesChanged { delegate: from, previous_votes, new_votes });
                }
                if to.is_non_zero() {
                    let mut trace = self.Votes_delegate_checkpoints.entry(to);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.into().latest() + amount);
                    self.emit(DelegateVotesChanged { delegate: to, previous_votes, new_votes });
                }
            }
        }

        /// Transfers, mints, or burns voting units.
        ///
        /// To register a mint, `from` should be zero. To register a burn, `to`
        /// should be zero. Total supply of voting units will be adjusted with mints and burns.
        ///
        /// May emit one or two `DelegateVotesChanged` events.
        fn transfer_voting_units(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            let block_timestamp = starknet::get_block_timestamp();
            if from.is_zero() {
                let mut trace = self.Votes_total_checkpoints.deref();
                trace.push(block_timestamp, trace.into().latest() + amount);
            }
            if to.is_zero() {
                let mut trace = self.Votes_total_checkpoints.deref();
                trace.push(block_timestamp, trace.into().latest() - amount);
            }
            self.move_delegate_votes(self.delegates(from), self.delegates(to), amount);
        }
    }
}

/// Common trait for tokens used for voting(e.g. `ERC721Votes` or `ERC20Votes`)
pub trait VotingUnitsTrait<TState> {
    fn get_voting_units(self: @TState, account: ContractAddress) -> u256;
}
