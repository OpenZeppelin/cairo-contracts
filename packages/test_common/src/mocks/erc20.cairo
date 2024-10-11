use starknet::ContractAddress;


#[starknet::contract]
pub mod DualCaseERC20Mock {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

#[starknet::contract]
pub mod SnakeERC20Mock {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

#[starknet::contract]
pub mod DualCaseERC20VotesMock {
    use openzeppelin_token::erc20::ERC20Component;
    use openzeppelin_token::erc20::extensions::ERC20VotesComponent::InternalTrait as ERC20VotesInternalTrait;
    use openzeppelin_token::erc20::extensions::ERC20VotesComponent;
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    component!(path: ERC20VotesComponent, storage: erc20_votes, event: ERC20VotesEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    // ERC20Votes
    #[abi(embed_v0)]
    impl ERC20VotesComponentImpl =
        ERC20VotesComponent::ERC20VotesImpl<ContractState>;

    // ERC20Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20_votes: ERC20VotesComponent::Storage,
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        #[substorage(v0)]
        pub nonces: NoncesComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20VotesEvent: ERC20VotesComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event
    }

    /// Required for hash computation.
    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'DAPP_NAME'
        }
        fn version() -> felt252 {
            'DAPP_VERSION'
        }
    }

    //
    // Hooks
    //

    impl ERC20VotesHooksImpl<
        TContractState,
        impl ERC20Votes: ERC20VotesComponent::HasComponent<TContractState>,
        impl HasComponent: ERC20Component::HasComponent<TContractState>,
        +NoncesComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC20Component::ERC20HooksTrait<TContractState> {
        fn after_update(
            ref self: ERC20Component::ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let mut erc20_votes_component = get_dep_component_mut!(ref self, ERC20Votes);
            erc20_votes_component.transfer_voting_units(from, recipient, amount);
        }
    }

    /// Sets the token `name` and `symbol`.
    /// Mints `fixed_supply` tokens to `recipient`.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        fixed_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, fixed_supply);
    }
}

#[derive(Drop, Serde, PartialEq, Debug, starknet::Store)]
pub enum Type {
    No,
    Before,
    After
}

#[starknet::interface]
pub trait IERC20ReentrantHelpers<TState> {
    fn schedule_reenter(
        ref self: TState,
        when: Type,
        target: ContractAddress,
        selector: felt252,
        calldata: Span<felt252>
    );
    fn function_call(ref self: TState);
    fn unsafe_mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn unsafe_burn(ref self: TState, account: ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IERC20Reentrant<TState> {
    fn schedule_reenter(
        ref self: TState,
        when: Type,
        target: ContractAddress,
        selector: felt252,
        calldata: Span<felt252>
    );
    fn function_call(ref self: TState);
    fn unsafe_mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn unsafe_burn(ref self: TState, account: ContractAddress, amount: u256);

    // IERC20
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::contract]
pub mod ERC20ReentrantMock {
    use openzeppelin_token::erc20::ERC20Component;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::storage::{Vec, MutableVecTrait};
    use starknet::syscalls::call_contract_syscall;
    use starknet::SyscallResultTrait;
    use super::Type;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        reenter_type: Type,
        reenter_target: ContractAddress,
        reenter_selector: felt252,
        reenter_calldata: Vec<felt252>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    //
    // Hooks
    //

    impl ERC20ReentrantImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let mut contract_state = self.get_contract_mut();

            if (contract_state.reenter_type.read() == Type::Before) {
                contract_state.reenter_type.write(Type::No);
                contract_state.function_call();
            }
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let mut contract_state = self.get_contract_mut();

            if (contract_state.reenter_type.read() == Type::After) {
                contract_state.reenter_type.write(Type::No);
                contract_state.function_call();
            }
        }
    }

    #[abi(embed_v0)]
    pub impl ERC20ReentrantHelpers of super::IERC20ReentrantHelpers<ContractState> {
        fn schedule_reenter(
            ref self: ContractState,
            when: Type,
            target: ContractAddress,
            selector: felt252,
            calldata: Span<felt252>
        ) {
            self.reenter_type.write(when);
            self.reenter_target.write(target);
            self.reenter_selector.write(selector);
            for elem in calldata {
                self.reenter_calldata.append().write(*elem);
            }
        }

        fn function_call(ref self: ContractState) {
            let target = self.reenter_target.read();
            let selector = self.reenter_selector.read();
            let mut calldata = array![];
            for i in 0
                ..self
                    .reenter_calldata
                    .len() {
                        calldata.append(self.reenter_calldata.at(i).read());
                    };
            call_contract_syscall(target, selector, calldata.span()).unwrap_syscall();
        }

        fn unsafe_mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.mint(recipient, amount);
        }

        fn unsafe_burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.erc20.burn(account, amount);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        self.erc20.initializer(name, symbol);
        self.reenter_type.write(Type::No);
    }
}
