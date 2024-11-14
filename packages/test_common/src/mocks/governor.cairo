#[starknet::contract]
pub mod GovernorMock {
    use openzeppelin_governance::governor::GovernorComponent::InternalTrait as GovernorInternalTrait;
    use openzeppelin_governance::governor::extensions::GovernorVotesComponent::InternalTrait;
    use openzeppelin_governance::governor::extensions::{
        GovernorVotesComponent, GovernorCountingSimpleComponent, GovernorCoreExecutionComponent
    };
    use openzeppelin_governance::governor::{GovernorComponent, DefaultConfig};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    pub const VOTING_DELAY: u64 = 86400; // 1 day
    pub const VOTING_PERIOD: u64 = 432_000; // 1 week
    pub const PROPOSAL_THRESHOLD: u256 = 10;
    pub const QUORUM: u256 = 100_000_000;

    component!(path: GovernorComponent, storage: governor, event: GovernorEvent);
    component!(path: GovernorVotesComponent, storage: governor_votes, event: GovernorVotesEvent);
    component!(
        path: GovernorCountingSimpleComponent,
        storage: governor_counting_simple,
        event: GovernorCountingSimpleEvent
    );
    component!(
        path: GovernorCoreExecutionComponent,
        storage: governor_core_execution,
        event: GovernorCoreExecutionEvent
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Governor
    #[abi(embed_v0)]
    impl GovernorImpl = GovernorComponent::GovernorImpl<ContractState>;

    // Extensions
    #[abi(embed_v0)]
    impl VotesTokenImpl = GovernorVotesComponent::VotesTokenImpl<ContractState>;
    impl GovernorVotesImpl = GovernorVotesComponent::GovernorVotes<ContractState>;
    impl GovernorCountingSimpleImpl =
        GovernorCountingSimpleComponent::GovernorCounting<ContractState>;
    impl GovernorCoreExecutionImpl =
        GovernorCoreExecutionComponent::GovernorExecution<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        pub governor: GovernorComponent::Storage,
        #[substorage(v0)]
        pub governor_votes: GovernorVotesComponent::Storage,
        #[substorage(v0)]
        pub governor_counting_simple: GovernorCountingSimpleComponent::Storage,
        #[substorage(v0)]
        pub governor_core_execution: GovernorCoreExecutionComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        GovernorEvent: GovernorComponent::Event,
        #[flat]
        GovernorVotesEvent: GovernorVotesComponent::Event,
        #[flat]
        GovernorCountingSimpleEvent: GovernorCountingSimpleComponent::Event,
        #[flat]
        GovernorCoreExecutionEvent: GovernorCoreExecutionComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, votes_token: ContractAddress) {
        self.governor.initializer();
        self.governor_votes.initializer(votes_token);
    }

    //
    // SNIP12 Metadata
    //

    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'DAPP_NAME'
        }

        fn version() -> felt252 {
            'DAPP_VERSION'
        }
    }

    //
    // Locally implemented extensions
    //

    impl GovernorQuorum of GovernorComponent::GovernorQuorumTrait<ContractState> {
        /// See `GovernorComponent::GovernorQuorumTrait::quorum`.
        fn quorum(self: @GovernorComponent::ComponentState<ContractState>, timepoint: u64) -> u256 {
            QUORUM
        }
    }

    pub impl GovernorSettings of GovernorComponent::GovernorSettingsTrait<ContractState> {
        /// See `GovernorComponent::GovernorSettingsTrait::voting_delay`.
        fn voting_delay(self: @GovernorComponent::ComponentState<ContractState>) -> u64 {
            VOTING_DELAY
        }

        /// See `GovernorComponent::GovernorSettingsTrait::voting_period`.
        fn voting_period(self: @GovernorComponent::ComponentState<ContractState>) -> u64 {
            VOTING_PERIOD
        }

        /// See `GovernorComponent::GovernorSettingsTrait::proposal_threshold`.
        fn proposal_threshold(self: @GovernorComponent::ComponentState<ContractState>) -> u256 {
            PROPOSAL_THRESHOLD
        }
    }
}
