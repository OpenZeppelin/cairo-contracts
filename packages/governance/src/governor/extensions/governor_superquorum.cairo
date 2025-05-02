// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo fork (wizard >= 0.11.1) based on OpenZeppelin Contracts v5.3.0 (governance/extensions/GovernorSuperQuorum.sol)
use starknet::ContractAddress;
use openzeppelin::governance::governor::governor::{ProposalId, ProposalState, ProposalCore};
use openzeppelin::governance::governor::interface::IGovernor;
use openzeppelin::governance::governor::governor::GovernorComponent;
use openzeppelin::governance::governor::governor::{
    GovernorExecution, GovernorCounting, GovernorVotesTrait, GovernorSettingsTrait, GovernorQuorumTrait
};

#[starknet::interface]
pub trait IGovernorSuperQuorum<TState> {
    /// @notice Minimum number of cast votes required for a proposal to reach super quorum.
    /// Only FOR votes are counted towards the super quorum. Once the super quorum is reached,
    /// an active proposal can proceed to the next state without waiting for the proposal deadline.
    /// @param timepoint The snapshot timepoint.
    /// @return The super quorum threshold.
    /// @dev WARNING: Ensure this value is greater than the regular quorum at the same timepoint
    /// to prevent proposals passing with fewer votes than the standard requirement.
    fn super_quorum(self: @TState, timepoint: u64) -> u256;

    // proposal_votes is implicitly required via the counting module used by the Governor
}

// Define the internal traits required by the component for it to function correctly.
// The contract embedding this component MUST provide implementations for these functions.
#[starknet::interface]
pub trait GovernorSuperQuorumInternal<TState> {
    /// @notice Accessor to the internal vote counts (against_votes, for_votes, abstain_votes).
    /// @dev CRITICAL: Must be implemented correctly, matching the return signature and logic
    /// of the specific counting module used by the Governor instance. Mismatches WILL cause errors.
    fn proposal_votes(
        self: @TState, proposal_id: ProposalId
    ) -> (u256, u256, u256); // E.g., (against, for, abstain)

    /// @notice Get the ProposalCore struct for a given proposal_id.
    /// @dev Must be implemented, typically by delegating to the base Governor component's
    /// internal logic for reading proposal storage.
    fn _proposal_core(self: @TState, proposal_id: ProposalId) -> ProposalCore;

    /// @notice The super quorum value for a given timepoint.
    /// @dev Must be implemented by the embedding contract. Consider the security implications
    /// of how this value is set and potentially changed.
    /// @dev See the warning in IGovernorSuperQuorum::super_quorum regarding comparison to regular quorum.
    fn super_quorum(self: @TState, timepoint: u64) -> u256;

    /// @notice Check if the vote succeeded for a given proposal_id.
    /// @dev Must be implemented, typically by delegating to the GovernorCounting trait
    /// implementation provided by the counting module.
    fn vote_succeeded(self: @TState, proposal_id: ProposalId) -> bool;

    /// @notice The regular quorum value for a given timepoint.
    /// @dev Required for the warning check. Typically delegates to GovernorQuorumTrait.
    fn quorum(self: @TState, timepoint: u64) -> u256;
}

#[starknet::component]
mod GovernorSuperQuorumComponent<
    TContractState,
    +HasComponent<TContractState>,
    +GovernorCounting<ComponentState<TContractState>>,
    +GovernorVotesTrait<ComponentState<TContractState>>,
    +GovernorSettingsTrait<ComponentState<TContractState>>,
    +GovernorQuorumTrait<ComponentState<TContractState>>,
    +GovernorSuperQuorumInternal<ComponentState<TContractState>>
> {
    use super::{ProposalId, ProposalState, ProposalCore, IGovernor, GovernorComponent};
    use super::GovernorExecution;
    use starknet::ComponentState;

    // --- Storage ---
    // No additional storage needed if super_quorum is defined by the implementing contract.

    // --- Internal ---
    // This overrides the state function defined in GovernorExecution
    mod GovernorExecutionInternalImpl {
        use starknet::ComponentState;
        use core::debug::PrintTrait; // For potential debug/panic messages
        use super::{ProposalId, ProposalState, ProposalCore, IGovernor, GovernorComponent};
        use super::super::GovernorSuperQuorumInternal;
        use super::super::super::governor::governor::{GovernorInternalTrait, GovernorExecution};
        use super::super::super::governor::governor::GovernorCounting;
        use super::super::super::governor::governor::Errors; // Assuming standard errors exist

        #[generate_trait]
        pub impl Internal<
            TContractState,
            +HasComponent<TContractState>,
            +GovernorCounting<ComponentState<TContractState>>,
            +GovernorSuperQuorumInternal<ComponentState<TContractState>>
        > of GovernorExecution::InternalTrait<TContractState> {
            fn state(
                self: @ComponentState<TContractState>, proposal_id: ProposalId
            ) -> ProposalState {
                let current_state = self.super().state(proposal_id);

                // Only potentially modify the state if it's currently Active
                if current_state != ProposalState::Active {
                    return current_state;
                }

                // Retrieve proposal details and snapshot timepoint
                // Assumes _proposal_core is correctly implemented via GovernorSuperQuorumInternal
                let proposal_core = self.GovernorSuperQuorumInternal__proposal_core(proposal_id);
                let snapshot = proposal_core.vote_start;

                // Retrieve super quorum threshold for the snapshot timepoint
                // Assumes super_quorum is correctly implemented via GovernorSuperQuorumInternal
                let super_quorum_threshold = self.GovernorSuperQuorumInternal_super_quorum(snapshot);

                // If super_quorum is zero, this extension effectively does nothing for this proposal.
                if super_quorum_threshold == 0 {
                     return ProposalState::Active;
                }

                // --- Sanity Check (Optional but recommended for integration debugging) ---
                // Retrieve regular quorum for comparison.
                // Assumes quorum is correctly implemented via GovernorSuperQuorumInternal
                let regular_quorum = self.GovernorSuperQuorumInternal_quorum(snapshot);
                // This assertion helps catch configuration errors during testing/CI.
                // It prevents accidentally allowing proposals to pass with fewer votes than the normal quorum.
                // If this assertion fails, it indicates a potential misconfiguration in the
                // `super_quorum` implementation of the host contract.
                assert(super_quorum_threshold >= regular_quorum, 'SuperQ > Quorum');

                // Retrieve vote counts
                // Assumes proposal_votes is correctly implemented via GovernorSuperQuorumInternal
                let (_, for_votes, _) = self
                    .GovernorSuperQuorumInternal_proposal_votes(proposal_id);

                // Check if FOR votes meet super quorum AND if the overall vote is successful
                // Assumes vote_succeeded is correctly implemented via GovernorSuperQuorumInternal
                let vote_has_succeeded = self.GovernorSuperQuorumInternal_vote_succeeded(proposal_id);

                if for_votes >= super_quorum_threshold && vote_has_succeeded {
                    // Super quorum met and vote succeeded, check if queuing is needed based on ETA
                    let eta = proposal_core.eta_seconds;
                    if eta == 0 {
                        // If no ETA is set (e.g., not using Timelock), moves directly to Succeeded
                        return ProposalState::Succeeded;
                    } else {
                        // If ETA is set, moves to Queued
                        return ProposalState::Queued;
                    }
                } else {
                    // Conditions not met, remain Active (until deadline or regular quorum)
                    return ProposalState::Active;
                }
            }
        }
    }

    // --- Aspects ---
    #[aspect]
    impl GovernorSuperQuorumAspect<
        TContractState,
        +HasComponent<TContractState>,
        +GovernorCounting<ComponentState<TContractState>>,
        +GovernorVotesTrait<ComponentState<TContractState>>,
        +GovernorSettingsTrait<ComponentState<TContractState>>,
        +GovernorQuorumTrait<ComponentState<TContractState>>,
        +GovernorSuperQuorumInternal<ComponentState<TContractState>>
    > of IGovernorSuperQuorum<ComponentState<TContractState>> {
        fn super_quorum(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            // Delegate to the internal trait implementation provided by the contract
            self.GovernorSuperQuorumInternal_super_quorum(timepoint)
        }
    }
} 