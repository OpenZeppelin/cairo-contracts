use starknet::ContractAddress;

#[starknet::contract]
#[with_components(ERC20)]
pub mod DualCaseERC20Mock {
    use openzeppelin_token::erc20::{DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

#[starknet::contract]
#[with_components(ERC20)]
pub mod SnakeERC20Mock {
    use openzeppelin_token::erc20::{DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

#[starknet::contract]
#[with_components(ERC20)]
pub mod ERC20CustomDecimalsMock {
    use openzeppelin_token::erc20::ERC20Component::ImmutableConfig;
    use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
    use starknet::ContractAddress;

    const CUSTOM_DECIMALS: u8 = 6;

    pub impl CustomDecimalsConfig of ImmutableConfig {
        const DECIMALS: u8 = CUSTOM_DECIMALS;
    }

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

/// Similar to `SnakeERC20Mock`, but emits events for `before_update` and `after_update` hooks.
/// This is used to test that the hooks are called with the correct arguments.
#[starknet::contract]
#[with_components(ERC20)]
pub mod SnakeERC20MockWithHooks {
    use openzeppelin_token::erc20::DefaultConfig;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BeforeUpdate: BeforeUpdate,
        AfterUpdate: AfterUpdate,
    }

    /// Event used to test that `before_update` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct BeforeUpdate {
        pub from: ContractAddress,
        pub recipient: ContractAddress,
        pub amount: u256,
    }

    /// Event used to test that `after_update` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct AfterUpdate {
        pub from: ContractAddress,
        pub recipient: ContractAddress,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }

    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(BeforeUpdate { from, recipient, amount });
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(AfterUpdate { from, recipient, amount });
        }
    }
}

#[starknet::contract]
#[with_components(ERC20, Nonces)]
pub mod DualCaseERC20PermitMock {
    use openzeppelin_token::erc20::{DefaultConfig, ERC20HooksEmptyImpl};
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    // ERC20Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // IERC20Permit
    #[abi(embed_v0)]
    impl ERC20PermitImpl = ERC20Component::ERC20PermitImpl<ContractState>;

    // ISNIP12Metadata
    #[abi(embed_v0)]
    impl SNIP12MetadataExternal =
        ERC20Component::SNIP12MetadataExternalImpl<ContractState>;

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

    /// Sets the token `name` and `symbol`.
    /// Mints `fixed_supply` tokens to `recipient`.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

#[derive(Drop, Serde, PartialEq, Debug, starknet::Store)]
pub enum Type {
    #[default]
    No,
    Before,
    After,
}

#[starknet::interface]
pub trait IERC20ReentrantHelpers<TState> {
    fn schedule_reenter(
        ref self: TState,
        when: Type,
        target: ContractAddress,
        selector: felt252,
        calldata: Span<felt252>,
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
        calldata: Span<felt252>,
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
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::contract]
#[with_components(ERC20)]
pub mod ERC20ReentrantMock {
    use openzeppelin_token::erc20::DefaultConfig;
    use starknet::storage::{
        MutableVecTrait, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
    };
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResultTrait};
    use super::Type;

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[storage]
    pub struct Storage {
        reenter_type: Type,
        reenter_target: ContractAddress,
        reenter_selector: felt252,
        reenter_calldata: Vec<felt252>,
    }

    //
    // Hooks
    //

    impl ERC20ReentrantImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();

            if contract_state.reenter_type.read() == Type::Before {
                contract_state.reenter_type.write(Type::No);
                contract_state.function_call();
            }
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();

            if contract_state.reenter_type.read() == Type::After {
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
            calldata: Span<felt252>,
        ) {
            self.reenter_type.write(when);
            self.reenter_target.write(target);
            self.reenter_selector.write(selector);
            for elem in calldata {
                self.reenter_calldata.push(*elem);
            }
        }

        fn function_call(ref self: ContractState) {
            let target = self.reenter_target.read();
            let selector = self.reenter_selector.read();
            let mut calldata = array![];
            for i in 0..self.reenter_calldata.len() {
                calldata.append(self.reenter_calldata.at(i).read());
            }
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

#[starknet::contract]
#[with_components(ERC20, ERC20Wrapper)]
pub mod ERC20WrapperMock {
    use openzeppelin_token::erc20::{DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20WrapperImpl = ERC20WrapperComponent::ERC20WrapperImpl<ContractState>;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[constructor]
    fn constructor(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, underlying: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20_wrapper.initializer(underlying);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn recover(ref self: ContractState, account: ContractAddress) -> u256 {
            self.erc20_wrapper.recover(account)
        }
    }
}

#[starknet::contract]
pub mod ERC20FlashMintMock {
    use openzeppelin_token::erc20::extensions::erc20_flash_mint::{
        DefaultConfig as FlashMintDefaultConfig, ERC20FlashMintComponent,
    };
    use openzeppelin_token::erc20::{
        DefaultConfig as ERC20DefaultConfig, ERC20Component, ERC20HooksEmptyImpl,
    };
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(
        path: ERC20FlashMintComponent, storage: erc20_flash_mint, event: ERC20FlashMintEvent,
    );

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20FlashMintImpl =
        ERC20FlashMintComponent::ERC20FlashMintImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        ERC20FlashMintEvent: ERC20FlashMintComponent::Event,
    }

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        #[substorage(v0)]
        pub erc20_flash_mint: ERC20FlashMintComponent::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

#[starknet::contract]
pub mod ERC20FlashMintConfiguredMock {
    use core::num::traits::Bounded;
    use openzeppelin_token::erc20::extensions::erc20_flash_mint::ERC20FlashMintComponent;
    use openzeppelin_token::erc20::{
        DefaultConfig as ERC20DefaultConfig, ERC20Component, ERC20HooksEmptyImpl,
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_contract_address};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(
        path: ERC20FlashMintComponent, storage: erc20_flash_mint, event: ERC20FlashMintEvent,
    );

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20FlashMintImpl =
        ERC20FlashMintComponent::ERC20FlashMintImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        ERC20FlashMintEvent: ERC20FlashMintComponent::Event,
    }

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        #[substorage(v0)]
        pub erc20_flash_mint: ERC20FlashMintComponent::Storage,
        configured_flash_fee: u256,
        configured_fee_receiver: ContractAddress,
        configured_flash_loan_cap: u256,
    }

    impl FlashMintConfigImpl of ERC20FlashMintComponent::FlashMintConfigTrait<ContractState> {
        fn max_flash_loan(
            self: @ERC20FlashMintComponent::ComponentState<ContractState>,
            token: ContractAddress,
            total_supply: u256,
        ) -> u256 {
            let this = get_contract_address();
            if token != this {
                return 0;
            }

            let contract_state = self.get_contract();
            let configured_cap = contract_state.configured_flash_loan_cap.read();
            let default_max_loan = Bounded::MAX - total_supply;

            if configured_cap < default_max_loan {
                configured_cap
            } else {
                default_max_loan
            }
        }

        fn flash_fee(
            self: @ERC20FlashMintComponent::ComponentState<ContractState>,
            token: ContractAddress,
            amount: u256,
        ) -> u256 {
            let _ = token;
            let _ = amount;
            self.get_contract().configured_flash_fee.read()
        }

        fn flash_fee_receiver(
            self: @ERC20FlashMintComponent::ComponentState<ContractState>,
        ) -> ContractAddress {
            self.get_contract().configured_fee_receiver.read()
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
        flash_fee: u256,
        fee_receiver: ContractAddress,
        flash_loan_cap: u256,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
        self.configured_flash_fee.write(flash_fee);
        self.configured_fee_receiver.write(fee_receiver);
        self.configured_flash_loan_cap.write(flash_loan_cap);
    }
}

#[starknet::contract]
pub mod ERC3156FlashBorrowerMock {
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::erc3156::IERC3156FlashBorrower;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        return_value: felt252,
        auto_approve: bool,
    }

    #[abi(embed_v0)]
    impl ERC3156FlashBorrowerImpl of IERC3156FlashBorrower<ContractState> {
        fn on_flash_loan(
            ref self: ContractState,
            initiator: ContractAddress,
            token: ContractAddress,
            amount: u256,
            fee: u256,
            data: Span<felt252>,
        ) -> felt252 {
            let _ = initiator;
            let _ = data;
            if self.auto_approve.read() {
                let lender = get_caller_address();
                let token_dispatcher = IERC20Dispatcher { contract_address: token };
                assert(
                    token_dispatcher.approve(lender, amount + fee), 'FlashBorrower: approve failed',
                );
            }
            self.return_value.read()
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, return_value: felt252, auto_approve: bool) {
        self.return_value.write(return_value);
        self.auto_approve.write(auto_approve);
    }
}

/// ERC20 mock whose `transfer`, `transfer_from`, and `approve` always return `false`. Used to test
/// `SafeERC20` failure paths.
#[starknet::contract]
pub mod ERC20ReturnFalseMock {
    use openzeppelin_interfaces::token::erc20::IERC20;
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {}

    #[abi(embed_v0)]
    pub impl ERC20ReturnFalseImpl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            0
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            0
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            0
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            false
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            false
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            false
        }
    }
}
