// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0
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
#[starknet::component]
pub mod ERC20WrapperComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::token::erc20::{IERC20, IERC20Wrapper};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::erc20::ERC20Component;
    use crate::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;

    #[storage]
    pub struct Storage {
        pub ERC20Wrapper_underlying: ContractAddress,
    }

    pub mod Errors {
        pub const INVALID_UNDERLYING_ADDRESS: felt252 = 'Wrapper: invalid underlying';
        pub const INVALID_SENDER: felt252 = 'Wrapper: invalid sender';
        pub const INVALID_RECEIVER: felt252 = 'Wrapper: invalid receiver';
        pub const TRANSFER_FAILED: felt252 = 'Wrapper: transfer failed';
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
            assert(receiver != this, Errors::INVALID_RECEIVER);

            let underlying = self.underlying();
            let token = IERC20Dispatcher { contract_address: underlying };
            let ok = token.transfer_from(caller, this, amount);
            assert(ok, Errors::TRANSFER_FAILED);

            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            erc20_component.mint(receiver, amount);
            true
        }

        /// Burns wrapped tokens from caller and sends underlying tokens to `receiver`.
        fn withdraw_to(
            ref self: ComponentState<TContractState>, receiver: ContractAddress, amount: u256,
        ) -> bool {
            let caller = starknet::get_caller_address();
            let this = starknet::get_contract_address();
            assert(receiver != this, Errors::INVALID_RECEIVER);

            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            erc20_component.burn(caller, amount);

            let underlying = self.underlying();
            let token = IERC20Dispatcher { contract_address: underlying };
            let ok = token.transfer(receiver, amount);
            assert(ok, Errors::TRANSFER_FAILED);
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
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Sets the underlying token address.
        fn initializer(ref self: ComponentState<TContractState>, underlying: ContractAddress) {
            let this = starknet::get_contract_address();
            assert(underlying.is_non_zero(), Errors::INVALID_UNDERLYING_ADDRESS);
            assert(underlying != this, Errors::INVALID_UNDERLYING_ADDRESS);
            self.ERC20Wrapper_underlying.write(underlying);
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

            // mint recoverable amount to specified account
            erc20_component.mint(account, value);
            value
        }
    }
}
