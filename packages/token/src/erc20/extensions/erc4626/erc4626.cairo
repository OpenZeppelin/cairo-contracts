// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (token/erc20/extensions/erc4626/erc4626.cairo)

/// # ERC4626 Component
///
/// ADD MEEEEEEEEEEEEEEEEE AHHHH
#[starknet::component]
pub mod ERC4626Component {
    use core::num::traits::{Bounded, Zero};
    use crate::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
    use crate::erc20::ERC20Component;
    use crate::erc20::extensions::erc4626::interface::IERC4626;
    use crate::erc20::interface::{IERC20, IERC20Metadata};
    use crate::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_utils::math::Rounding;
    use openzeppelin_utils::math;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    // The defualt values are only used when the DefaultConfig
    // is in scope in the implementing contract.
    pub const DEFAULT_UNDERLYING_DECIMALS: u8 = 18;
    pub const DEFAULT_DECIMALS_OFFSET: u8 = 0;

    #[storage]
    pub struct Storage {
        ERC4626_asset: ContractAddress
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Deposit {
        #[key]
        pub sender: ContractAddress,
        #[key]
        pub owner: ContractAddress,
        pub assets: u256,
        pub shares: u256
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Withdraw {
        #[key]
        pub sender: ContractAddress,
        #[key]
        pub receiver: ContractAddress,
        #[key]
        pub owner: ContractAddress,
        pub assets: u256,
        pub shares: u256
    }

    pub mod Errors {
        pub const EXCEEDED_MAX_DEPOSIT: felt252 = 'ERC4626: exceeds max deposit';
        pub const EXCEEDED_MAX_MINT: felt252 = 'ERC4626: exceeds max mint';
        pub const EXCEEDED_MAX_WITHDRAW: felt252 = 'ERC4626: exceeds max withdraw';
        pub const EXCEEDED_MAX_REDEEM: felt252 = 'ERC4626: exceeds max redeem';
        pub const TOKEN_TRANSFER_FAILED: felt252 = 'ERC4626: token transfer failed';
        pub const INVALID_ASSET_ADDRESS: felt252 = 'ERC4626: asset address set to 0';
        pub const DECIMALS_OVERFLOW: felt252 = 'ERC4626: decimals overflow';
    }

    /// Constants expected to be defined at the contract level used to configure the component
    /// behaviour.
    ///
    /// ADD ME...
    pub trait ImmutableConfig {
        const UNDERLYING_DECIMALS: u8;
        const DECIMALS_OFFSET: u8;

        fn validate() {
            assert(
                Bounded::MAX - Self::UNDERLYING_DECIMALS >= Self::DECIMALS_OFFSET,
                Errors::DECIMALS_OVERFLOW
            )
        }
    }

    #[embeddable_as(ERC4626Impl)]
    impl ERC4626<
        TContractState,
        +HasComponent<TContractState>,
        impl Immutable: ImmutableConfig,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>
    > of IERC4626<ComponentState<TContractState>> {
        fn asset(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ERC4626_asset.read()
        }

        fn total_assets(self: @ComponentState<TContractState>) -> u256 {
            let this = starknet::get_contract_address();
            IERC20Dispatcher { contract_address: self.ERC4626_asset.read() }.balance_of(this)
        }

        fn convert_to_shares(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets, Rounding::Floor)
        }

        fn convert_to_assets(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares, Rounding::Floor)
        }

        fn max_deposit(self: @ComponentState<TContractState>, receiver: ContractAddress) -> u256 {
            Bounded::MAX
        }

        fn preview_deposit(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets, Rounding::Floor)
        }

        fn deposit(
            ref self: ComponentState<TContractState>, assets: u256, receiver: ContractAddress
        ) -> u256 {
            let max_assets = self.max_deposit(receiver);
            assert(assets <= max_assets, Errors::EXCEEDED_MAX_DEPOSIT);

            let shares = self.preview_deposit(assets);
            let caller = starknet::get_caller_address();
            self._deposit(caller, receiver, assets, shares);
            shares
        }

        fn max_mint(self: @ComponentState<TContractState>, receiver: ContractAddress) -> u256 {
            Bounded::MAX
        }

        fn preview_mint(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares, Rounding::Ceil)
        }

        fn mint(
            ref self: ComponentState<TContractState>, shares: u256, receiver: ContractAddress
        ) -> u256 {
            let max_shares = self.max_mint(receiver);
            assert(shares <= max_shares, Errors::EXCEEDED_MAX_MINT);

            let assets = self.preview_mint(shares);
            let caller = starknet::get_caller_address();
            self._deposit(caller, receiver, assets, shares);
            assets
        }

        fn max_withdraw(self: @ComponentState<TContractState>, owner: ContractAddress) -> u256 {
            let erc20_component = get_dep_component!(self, ERC20);
            let owner_bal = erc20_component.balance_of(owner);
            self._convert_to_assets(owner_bal, Rounding::Floor)
        }

        fn preview_withdraw(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            self._convert_to_shares(assets, Rounding::Ceil)
        }

        fn withdraw(
            ref self: ComponentState<TContractState>,
            assets: u256,
            receiver: ContractAddress,
            owner: ContractAddress
        ) -> u256 {
            let max_assets = self.max_withdraw(owner);
            assert(assets <= max_assets, Errors::EXCEEDED_MAX_WITHDRAW);

            let shares = self.preview_withdraw(assets);
            let caller = starknet::get_caller_address();
            self._withdraw(caller, receiver, owner, assets, shares);

            shares
        }

        fn max_redeem(self: @ComponentState<TContractState>, owner: ContractAddress) -> u256 {
            let erc20_component = get_dep_component!(self, ERC20);
            erc20_component.balance_of(owner)
        }

        fn preview_redeem(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            self._convert_to_assets(shares, Rounding::Floor)
        }

        fn redeem(
            ref self: ComponentState<TContractState>,
            shares: u256,
            receiver: ContractAddress,
            owner: ContractAddress
        ) -> u256 {
            let max_shares = self.max_redeem(owner);
            assert(shares <= max_shares, Errors::EXCEEDED_MAX_REDEEM);

            let assets = self.preview_redeem(shares);
            let caller = starknet::get_caller_address();
            self._withdraw(caller, receiver, owner, assets, shares);

            assets
        }
    }

    #[embeddable_as(ERC4626MetadataImpl)]
    impl ERC4626Metadata<
        TContractState,
        +HasComponent<TContractState>,
        impl Immutable: ImmutableConfig,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
    > of IERC20Metadata<ComponentState<TContractState>> {
        /// Returns the name of the token.
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            let erc20_component = get_dep_component!(self, ERC20);
            erc20_component.ERC20_name.read()
        }

        /// Returns the ticker symbol of the token, usually a shorter version of the name.
        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            let erc20_component = get_dep_component!(self, ERC20);
            erc20_component.ERC20_symbol.read()
        }

        /// Returns the number of decimals used to get its user representation.
        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            Immutable::UNDERLYING_DECIMALS + Immutable::DECIMALS_OFFSET
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Immutable: ImmutableConfig,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, asset_address: ContractAddress) {
            ImmutableConfig::validate();
            assert(!asset_address.is_zero(), Errors::INVALID_ASSET_ADDRESS);
            self.ERC4626_asset.write(asset_address);
        }

        fn _deposit(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256
        ) {
            // Transfer assets first
            let this = starknet::get_contract_address();
            let asset_dispatcher = IERC20Dispatcher { contract_address: self.ERC4626_asset.read() };
            assert(
                asset_dispatcher.transfer_from(caller, this, assets), Errors::TOKEN_TRANSFER_FAILED
            );

            // Mint shares after transferring assets
            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            erc20_component.mint(receiver, shares);
            self.emit(Deposit { sender: caller, owner: receiver, assets, shares });
        }

        fn _withdraw(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256
        ) {
            // Burn shares first
            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            if (caller != owner) {
                erc20_component._spend_allowance(owner, caller, shares);
            }
            erc20_component.burn(owner, shares);

            // Transfer assets after burn
            let asset_dispatcher = IERC20Dispatcher { contract_address: self.ERC4626_asset.read() };
            asset_dispatcher.transfer(receiver, assets);

            self.emit(Withdraw { sender: caller, receiver, owner, assets, shares });
        }

        fn _convert_to_shares(
            self: @ComponentState<TContractState>, assets: u256, rounding: Rounding
        ) -> u256 {
            let mut erc20_component = get_dep_component!(self, ERC20);
            let total_supply = erc20_component.total_supply();

            math::u256_mul_div(
                assets,
                total_supply + math::power(10, Immutable::DECIMALS_OFFSET.into()),
                self.total_assets() + 1,
                rounding
            )
        }

        fn _convert_to_assets(
            self: @ComponentState<TContractState>, shares: u256, rounding: Rounding
        ) -> u256 {
            let mut erc20_component = get_dep_component!(self, ERC20);
            let total_supply = erc20_component.total_supply();

            math::u256_mul_div(
                shares,
                self.total_assets() + 1,
                total_supply + math::power(10, Immutable::DECIMALS_OFFSET.into()),
                rounding
            )
        }
    }
}

/// Implementation of the default ERC2981Component ImmutableConfig.
///
/// See
/// https://github.com/starknet-io/SNIPs/blob/963848f0752bde75c7087c2446d83b7da8118b25/SNIPS/snip-107.md#defaultconfig-implementation
///
/// The default underlying decimals is set to `18`.
/// The default decimals offset is set to `0`.
pub impl DefaultConfig of ERC4626Component::ImmutableConfig {
    const UNDERLYING_DECIMALS: u8 = ERC4626Component::DEFAULT_UNDERLYING_DECIMALS;
    const DECIMALS_OFFSET: u8 = ERC4626Component::DEFAULT_DECIMALS_OFFSET;
}

#[cfg(test)]
mod Test {
    use openzeppelin_test_common::mocks::erc4626::ERC4626Mock;
    use starknet::contract_address_const;
    use super::ERC4626Component::InternalImpl;
    use super::ERC4626Component;

    type ComponentState = ERC4626Component::ComponentState<ERC4626Mock::ContractState>;

    fn COMPONENT_STATE() -> ComponentState {
        ERC4626Component::component_state_for_testing()
    }

    // Invalid fee denominator
    impl InvalidImmutableConfig of ERC4626Component::ImmutableConfig {
        const UNDERLYING_DECIMALS: u8 = 255;
        const DECIMALS_OFFSET: u8 = 1;
    }

    #[test]
    #[should_panic(expected: 'ERC4626: decimals overflow')]
    fn test_initializer_invalid_config_panics() {
        let mut state = COMPONENT_STATE();
        let asset = contract_address_const::<'ASSET'>();

        state.initializer(asset);
    }
}

