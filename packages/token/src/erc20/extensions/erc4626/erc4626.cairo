// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (token/erc20/extensions/erc4626/erc4626.cairo)

/// # ERC4626 Component
///
/// ADD MEEEEEEEEEEEEEEEEE AHHHH
#[starknet::component]
pub mod ERC4626Component {
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
    pub enum Event {}

    pub mod Errors {}

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
        +ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>
    > of IERC4626<ComponentState<TContractState>> {
        fn asset(self: @ComponentState<TContractState>) -> ContractAddress {
            let this = starknet::get_contract_address();
            return this;
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