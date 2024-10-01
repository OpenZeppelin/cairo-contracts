// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (token/erc20/extensions/erc4626/erc4626.cairo)

/// # ERC4626 Component
///
/// ADD MEEEEEEEEEEEEEEEEE AHHHH
#[starknet::component]
pub mod ERC4626Component {
    use core::num::traits::Bounded;
    use crate::erc20::extensions::erc4626::interface::IERC4626;
    use crate::erc20::ERC20Component;
    use crate::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
    use crate::erc20::interface::IERC20;
    use crate::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;
    //use starknet::storage::{
    //    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess
    //};

    // This default decimals is only used when the DefaultConfig
    // is in scope in the implementing contract.
    pub const DEFAULT_DECIMALS: u8 = 18;

    #[storage]
    pub struct Storage {}

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
        pub const EXCEEDED_MAX_WITHDRAWAL: felt252 = 'ERC4626: exceeds max withdrawal';
        pub const EXCEEDED_MAX_REDEEM: felt252 = 'ERC4626: exceeds max redeem';
        pub const TOKEN_TRANSFER_FAILED: felt252 = 'ERC4626: Token transfer failed';
    }

    /// Constants expected to be defined at the contract level used to configure the component
    /// behaviour.
    ///
    ///
    pub trait ImmutableConfig {
        const ASSET: ContractAddress;
        const UNDERLYING_DECIMALS: u128;
        const DECIMALS_OFFSET: u8;

        fn validate() {}
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
            Immutable::ASSET
        }

        fn total_assets(self: @ComponentState<TContractState>) -> u256 {
            let this = starknet::get_contract_address();
            IERC20Dispatcher{ contract_address: Immutable::ASSET }.balance_of(this)
        }

        fn convert_to_shares(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            //self._convert_to_shares(assets)
            1
        }

        fn convert_to_assets(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            //self._convert_to_assets(shares)
            1
        }

        fn max_deposit(self: @ComponentState<TContractState>, receiver: ContractAddress) -> u256 {
            Bounded::MAX
        }

        fn preview_deposit(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            //self._convertToShares(assets, Math.Rounding.Floor);
            1
        }

        fn deposit(ref self: ComponentState<TContractState>, assets: u256, receiver: ContractAddress) -> u256 {
            let max_assets = self.max_deposit(receiver);
            assert(assets < max_assets, Errors::EXCEEDED_MAX_DEPOSIT);

            let shares = self.preview_deposit(assets);
            let caller = starknet::get_caller_address();
            self._deposit(caller, receiver, assets, shares);
            shares
        }

        fn max_mint(self: @ComponentState<TContractState>, receiver: ContractAddress) -> u256 {
            Bounded::MAX
        }

        fn preview_mint(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            //return _convertToAssets(shares, Math.Rounding.Ceil);
            1
        }

        fn mint(
            ref self: ComponentState<TContractState>, shares: u256, receiver: ContractAddress
        ) -> u256 {
            let max_shares = self.max_mint(receiver);
            assert(shares < max_shares, Errors::EXCEEDED_MAX_MINT);

            let assets = self.preview_mint(shares);
            let caller = starknet::get_caller_address();
            self._deposit(caller, receiver, assets, shares);
            assets
        }

        fn max_withdrawal(self: @ComponentState<TContractState>, owner: ContractAddress) -> u256 {
            //return _convertToAssets(balanceOf(owner), Math.Rounding.Floor);

            //let erc20_component = get_dep_component!(self, ERC20);
            //let owner_bal = erc20_component.balance_of(owner);
            //self._convert_to_assets(owner_bal);
            1
        }

        fn preview_withdrawal(self: @ComponentState<TContractState>, assets: u256) -> u256 {
            //return _convertToShares(assets, Math.Rounding.Ceil);

            // self._convert_to_shares(assets);
            1
        }

        fn withdraw(
            ref self: ComponentState<TContractState>, assets: u256, receiver: ContractAddress, owner: ContractAddress
        ) -> u256 {
            let max_assets = self.max_withdrawal(owner);
            assert(assets < max_assets, Errors::EXCEEDED_MAX_WITHDRAWAL);

            let shares = self.preview_withdrawal(assets);
            let _caller = starknet::get_caller_address();
            //self._withdraw(_caller, receiver, owner, assets, shares);
            shares
        }

        fn max_redeem(self: @ComponentState<TContractState>, owner: ContractAddress) -> u256 {
            let erc20_component = get_dep_component!(self, ERC20);
            erc20_component.balance_of(owner)
        }

        fn preview_redeem(self: @ComponentState<TContractState>, shares: u256) -> u256 {
            //self._convert_to_assets(shares)
            1
        }

        fn redeem(
            ref self: ComponentState<TContractState>, shares: u256, receiver: ContractAddress, owner: ContractAddress
        ) -> u256 {
            let max_shares = self.max_redeem(owner);
            assert(shares < max_shares, Errors::EXCEEDED_MAX_REDEEM);

            let assets = self.preview_redeem(shares);
            let _caller = starknet::get_caller_address();
            //self._withdraw(_caller, receiver, owner, assets, shares);
            assets
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
        fn initializer(
            ref self: ComponentState<TContractState>) {
            //ImmutableConfig::validate();
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
            let asset_dispatcher = IERC20Dispatcher { contract_address: Immutable::ASSET };
            assert(asset_dispatcher.transfer_from(caller, this, assets), Errors::TOKEN_TRANSFER_FAILED);

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
            let asset_dispatcher = IERC20Dispatcher { contract_address: Immutable::ASSET };
            asset_dispatcher.transfer(receiver, assets);

            self.emit(Withdraw { sender: caller, receiver, owner, assets, shares });
        }
    }
}

/// Implementation of the default ERC2981Component ImmutableConfig.
///
/// See
/// https://github.com/starknet-io/SNIPs/blob/963848f0752bde75c7087c2446d83b7da8118b25/SNIPS/snip-107.md#defaultconfig-implementation
///
/// The default decimals is set to `DEFAULT_DECIMALS`.
//pub impl DefaultConfig of ERC2981Component::ImmutableConfig {
//    const UNDERLYING_DECIMALS: u8 = ERC4626::DEFAULT_DECIMALS;
//}