// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.0
// (token/src/erc20/extensions/erc20_wrapper.cairo)

/// # ERC20Wrapper Component
///
/// Users can deposit and withdraw "underlying tokens" and receive a matching number of "wrapped
/// tokens". This is useful in conjunction with other modules. For example, combining this wrapping
/// mechanism with the ERC20VotesComponent will allow the wrapping of an existing "basic" ERC-20
/// into a governance token.
///
/// WARNING: Any mechanism in which the underlying token changes the `balanceOf` of an account
/// without an explicit transfer may desynchronize this contract's supply and its underlying
/// balance. Please exercise caution when wrapping tokens that may undercollateralize the wrapper
/// (i.e. the wrapper's total supply is higher than its underlying balance). See `recover` for
/// recovering value accrued to the wrapper.
///
/// IMPORTANT: The underlying token must implement IERC20Metadata and have the same decimals as the
/// wrapper. This is enforced in the initializer.
#[starknet::component]
pub mod ERC20WrapperComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc20::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
        IERC20MetadataDispatcherTrait,
    };
    use openzeppelin_interfaces::token::erc20::{IERC20, IERC20Wrapper};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::erc20::ERC20Component;
    use crate::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;

    #[storage]
    pub struct Storage {
        pub ERC20Wrapper_underlying: ContractAddress,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    /// Emitted when `caller` deposits `assets` and transfers those
    /// `assets` to `receiver`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Deposit {
        #[key]
        pub sender: ContractAddress,
        #[key]
        pub receiver: ContractAddress,
        pub assets: u256,
    }

    /// Emitted when `caller` withdraws `assets` and transfers those
    /// `assets` to `receiver`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Withdraw {
        #[key]
        pub caller: ContractAddress,
        #[key]
        pub receiver: ContractAddress,
        pub assets: u256,
    }

    pub mod Errors {
        pub const INVALID_UNDERLYING_ADDRESS: felt252 = 'Wrapper: invalid underlying';
        pub const INVALID_SENDER: felt252 = 'Wrapper: invalid sender';
        pub const INVALID_RECEIVER: felt252 = 'Wrapper: invalid receiver';
        pub const TRANSFER_FAILED: felt252 = 'Wrapper: transfer failed';
        pub const NOTHING_TO_RECOVER: felt252 = 'Wrapper: nothing to recover';
        pub const INVALID_DECIMALS: felt252 = 'Wrapper: invalid decimals';
    }

    //
    // External
    //

    #[embeddable_as(ERC20WrapperImpl)]
    impl ERC20Wrapper<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of IERC20Wrapper<ComponentState<TContractState>> {
        /// Returns the address of the underlying token used for the wrapper.
        fn underlying(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ERC20Wrapper_underlying.read()
        }

        /// Deposits underlying tokens and mints the same amount of wrapped tokens to `receiver`.
        fn deposit_for(
            ref self: ComponentState<TContractState>, receiver: ContractAddress, amount: u256,
        ) -> bool {
            let caller = starknet::get_caller_address();
            let this = starknet::get_contract_address();
            assert(caller != this, Errors::INVALID_SENDER);
            assert(receiver.is_non_zero(), Errors::INVALID_RECEIVER);
            assert(receiver != this, Errors::INVALID_RECEIVER);

            let underlying = self.underlying();
            let token = IERC20Dispatcher { contract_address: underlying };
            let ok = token.transfer_from(caller, this, amount);
            assert(ok, Errors::TRANSFER_FAILED);

            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            erc20_component.mint(receiver, amount);

            self.emit(Deposit { sender: caller, receiver, assets: amount });
            true
        }

        /// Burns wrapped tokens from caller and sends underlying tokens to `receiver`.
        fn withdraw_to(
            ref self: ComponentState<TContractState>, receiver: ContractAddress, amount: u256,
        ) -> bool {
            let caller = starknet::get_caller_address();
            let this = starknet::get_contract_address();
            assert(receiver.is_non_zero(), Errors::INVALID_RECEIVER);
            assert(receiver != this, Errors::INVALID_RECEIVER);

            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            erc20_component.burn(caller, amount);

            let underlying = self.underlying();
            let token = IERC20Dispatcher { contract_address: underlying };
            let ok = token.transfer(receiver, amount);
            assert(ok, Errors::TRANSFER_FAILED);

            self.emit(Withdraw { caller, receiver, assets: amount });
            true
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        impl ERC20ImmutableConfig: ERC20Component::ImmutableConfig,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Sets the underlying token address.
        ///
        /// Requirements:
        /// - `underlying` cannot be the zero address.
        /// - `underlying` cannot be the same as the contract address.
        /// - The underlying token must implement IERC20Metadata.
        /// - The underlying token must have the same decimals as the wrapper.
        fn initializer(ref self: ComponentState<TContractState>, underlying: ContractAddress) {
            let this = starknet::get_contract_address();
            assert(underlying.is_non_zero(), Errors::INVALID_UNDERLYING_ADDRESS);
            assert(underlying != this, Errors::INVALID_UNDERLYING_ADDRESS);
            self.ERC20Wrapper_underlying.write(underlying);

            // Validate that decimals are the same
            let underlying_token = IERC20MetadataDispatcher { contract_address: underlying };
            let underlying_decimals = underlying_token.decimals();
            let wrapper_decimals = ERC20ImmutableConfig::DECIMALS;
            assert(underlying_decimals == wrapper_decimals, Errors::INVALID_DECIMALS);
        }

        /// Mints wrapped tokens to cover any underlying tokens that were transferred to this
        /// contract by mistake, or acquired via rebasing mechanisms. Internal function that can be
        /// exposed with access control if desired.
        fn recover(ref self: ComponentState<TContractState>, account: ContractAddress) -> u256 {
            let underlying = self.underlying();
            let this = starknet::get_contract_address();

            // get underlying balance held by this contract
            let token = IERC20Dispatcher { contract_address: underlying };
            let underlying_balance = token.balance_of(this);

            // get current total supply of wrapped tokens
            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            let total_supply = erc20_component.total_supply();

            // calculate recoverable amount
            let value = underlying_balance - total_supply;

            // if there is nothing to recover, revert
            assert(value.is_non_zero(), Errors::NOTHING_TO_RECOVER);

            // mint recoverable amount to specified account
            erc20_component.mint(account, value);
            value
        }
    }
}
