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
    use crate::erc20::interface::IERC20;
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
    }

    /// Constants expected to be defined at the contract level used to configure the component
    /// behaviour.
    ///
    ///
    //pub trait ImmutableConfig {
    //    const ASSET: ContractAddress;
    //    const DECIMALS: u128;
//
    //    fn validate() {}
    //}

    #[embeddable_as(ERC4626Impl)]
    impl ERC4626<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>
    > of IERC4626<ComponentState<TContractState>> {
        fn asset(self: @ComponentState<TContractState>) -> ContractAddress {
            let this = starknet::get_contract_address();
            return this;
        }

        fn total_assets(self: @ComponentState<TContractState>) -> u256 {
            let this = starknet::get_contract_address();
            let erc20_component = get_dep_component!(self, ERC20);
            erc20_component.balance_of(this)
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
            let _caller = starknet::get_caller_address();
            //self._deposit(caller, receiver, assets, shares);
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
            let _caller = starknet::get_caller_address();
            //self._deposit(caller, receiver, assets, shares);
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
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        //impl Immutable: ImmutableConfig,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>) {
            //ImmutableConfig::validate();
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