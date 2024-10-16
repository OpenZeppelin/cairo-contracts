// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (governance/governor/governor.cairo)

/// # Governor Component
///
/// Core of the governance system.
#[starknet::component]
pub mod GovernorComponent {
    use crate::governor::ProposalCore;
    use openzeppelin_utils::structs::DoubleEndedQueue;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    pub struct Storage {
        proposals: Map<felt252, ProposalCore>,
        governance_call: DoubleEndedQueue
    }

    mod Errors {
        pub const INVALID_ROYALTY: felt252 = 'ERC2981: invalid royalty';
    }

    /// Constants expected to be defined at the contract level used to configure the component
    /// behaviour.
    ///
    /// - `FEE_DENOMINATOR`: The denominator with which to interpret the fee set in
    ///   `set_token_royalty` and `set_default_royalty` as a fraction of the sale price.
    ///
    /// Requirements:
    ///
    /// - `FEE_DENOMINATOR` must be greater than 0.
    pub trait ImmutableConfig {
        const FEE_DENOMINATOR: u128;

        fn validate() {
            assert(Self::FEE_DENOMINATOR > 0, Errors::INVALID_FEE_DENOMINATOR);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn assert_only_governance(ref self: ComponentState<TContractState>) {
            
        }

        fn executor(self: @ComponentState<TContractState>) -> ContractAddress {
            starknet::get_contract_address()
        }
    }
}
