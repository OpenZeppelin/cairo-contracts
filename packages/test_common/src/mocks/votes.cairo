#[starknet::contract]
#[with_components(ERC20, Votes, Nonces)]
pub mod LegacyERC20VotesMock {
    use openzeppelin_interfaces::votes::IVotes;
    use openzeppelin_token::erc20::DefaultConfig;
    use openzeppelin_utils::contract_clock::ERC6372TimestampClock;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    /// Required for hash computation.
    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'DAPP_NAME'
        }
        fn version() -> felt252 {
            'DAPP_VERSION'
        }
    }

    // Votes
    #[abi(per_item)]
    #[generate_trait]
    impl VotesImpl of LegacyVotesABI {
        fn get_votes(self: @ContractState, account: ContractAddress) -> u256 {
            self.votes.get_votes(account)
        }

        fn get_past_votes(self: @ContractState, account: ContractAddress, timepoint: u64) -> u256 {
            self.votes.get_past_votes(account, timepoint)
        }

        fn get_past_total_supply(self: @ContractState, timepoint: u64) -> u256 {
            self.votes.get_past_total_supply(timepoint)
        }

        fn delegates(self: @ContractState, account: ContractAddress) -> ContractAddress {
            self.votes.delegates(account)
        }

        fn delegate(ref self: ContractState, delegatee: ContractAddress) {
            self.votes.delegate(delegatee)
        }

        fn delegate_by_sig(
            ref self: ContractState,
            delegator: ContractAddress,
            delegatee: ContractAddress,
            nonce: felt252,
            expiry: u64,
            signature: Span<felt252>,
        ) {
            self.votes.delegate_by_sig(delegator, delegatee, nonce, expiry, signature)
        }
    }

    impl ERC20VotesHooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.votes.transfer_voting_units(from, recipient, amount);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("MyToken", "MTK");
    }
}

#[starknet::contract]
#[with_components(ERC20, Votes, Nonces)]
pub mod ERC20TimestampVotesMock {
    use openzeppelin_token::erc20::DefaultConfig;
    use openzeppelin_utils::contract_clock::ERC6372TimestampClock;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    // Votes
    #[abi(embed_v0)]
    impl VotesImpl = VotesComponent::VotesImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    /// Required for hash computation.
    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'DAPP_NAME'
        }
        fn version() -> felt252 {
            'DAPP_VERSION'
        }
    }

    impl ERC20VotesHooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.votes.transfer_voting_units(from, recipient, amount);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("MyToken", "MTK");
    }
}

#[starknet::contract]
#[with_components(ERC20, Votes, Nonces)]
pub mod ERC20BlockNumberVotesMock {
    use openzeppelin_token::erc20::DefaultConfig;
    use openzeppelin_utils::contract_clock::ERC6372BlockNumberClock;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    // Votes
    #[abi(embed_v0)]
    impl VotesImpl = VotesComponent::VotesImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    /// Required for hash computation.
    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'DAPP_NAME'
        }
        fn version() -> felt252 {
            'DAPP_VERSION'
        }
    }

    impl ERC20VotesHooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.votes.transfer_voting_units(from, recipient, amount);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("MyToken", "MTK");
    }
}

#[starknet::contract]
#[with_components(ERC721, Votes, SRC5, Nonces)]
pub mod ERC721TimestampVotesMock {
    use openzeppelin_utils::contract_clock::ERC6372TimestampClock;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    // Votes
    #[abi(embed_v0)]
    impl VotesImpl = VotesComponent::VotesImpl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    /// Required for hash computation.
    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'DAPP_NAME'
        }
        fn version() -> felt252 {
            'DAPP_VERSION'
        }
    }

    impl ERC721VotesHooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        // We need to use the `before_update` hook to check the previous owner
        // before the transfer is executed.
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract_state = self.get_contract_mut();

            // We use the internal function here since it does not check if the token id exists
            // which is necessary for mints
            let previous_owner = self._owner_of(token_id);
            contract_state.votes.transfer_voting_units(previous_owner, to, 1);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("MyToken", "MTK", "");
    }
}

#[starknet::contract]
#[with_components(ERC721, Votes, SRC5, Nonces)]
pub mod ERC721BlockNumberVotesMock {
    use openzeppelin_utils::contract_clock::ERC6372BlockNumberClock;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    // Votes
    #[abi(embed_v0)]
    impl VotesImpl = VotesComponent::VotesImpl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    /// Required for hash computation.
    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'DAPP_NAME'
        }
        fn version() -> felt252 {
            'DAPP_VERSION'
        }
    }

    impl ERC721VotesHooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        // We need to use the `before_update` hook to check the previous owner
        // before the transfer is executed.
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract_state = self.get_contract_mut();

            // We use the internal function here since it does not check if the token id exists
            // which is necessary for mints
            let previous_owner = self._owner_of(token_id);
            contract_state.votes.transfer_voting_units(previous_owner, to, 1);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("MyToken", "MTK", "");
    }
}
