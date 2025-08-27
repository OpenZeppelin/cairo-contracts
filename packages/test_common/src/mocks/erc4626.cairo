#[starknet::contract]
#[with_components(ERC20, ERC4626)]
pub mod ERC4626Mock {
    use openzeppelin_token::erc20::extensions::erc4626::{
        DefaultConfig, ERC4626DefaultNoFees, ERC4626DefaultNoLimits, ERC4626EmptyHooks,
        ERC4626SelfAssetsManagement,
    };
    use openzeppelin_token::erc20::{DefaultConfig as ERC20DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    // ERC4626
    #[abi(embed_v0)]
    impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
    // ERC4626MetadataImpl is a custom impl of IERC20Metadata
    #[abi(embed_v0)]
    impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        underlying_asset: ContractAddress,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
        self.erc4626.initializer(underlying_asset);
    }
}

#[starknet::contract]
#[with_components(ERC20, ERC4626)]
pub mod ERC4626ExternalVaultMock {
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc20::extensions::erc4626::{
        ERC4626DefaultNoFees, ERC4626DefaultNoLimits, ERC4626EmptyHooks,
    };
    use openzeppelin_token::erc20::{DefaultConfig as ERC20DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    // ERC4626
    #[abi(embed_v0)]
    impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
    // ERC4626MetadataImpl is a custom impl of IERC20Metadata
    #[abi(embed_v0)]
    impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[storage]
    pub struct Storage {
        external_storage: ContractAddress,
    }

    pub impl OffsetConfig of ERC4626Component::ImmutableConfig {
        const UNDERLYING_DECIMALS: u8 = ERC4626Component::DEFAULT_UNDERLYING_DECIMALS;
        const DECIMALS_OFFSET: u8 = 1;
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        underlying_asset: ContractAddress,
        external_storage: ContractAddress,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.external_storage.write(external_storage);
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
        self.erc4626.initializer(underlying_asset);
    }

    impl ERC4626ExternalAssetsManagement of ERC4626Component::AssetsManagementTrait<ContractState> {
        fn transfer_assets_in(
            ref self: ERC4626Component::ComponentState<ContractState>,
            from: ContractAddress,
            assets: u256,
        ) {
            let asset_storage = self.get_contract().external_storage.read();
            let asset_dispatcher = IERC20Dispatcher { contract_address: self.ERC4626_asset.read() };
            assert(
                asset_dispatcher.transfer_from(from, asset_storage, assets),
                ERC4626Component::Errors::TOKEN_TRANSFER_FAILED,
            );
        }

        fn transfer_assets_out(
            ref self: ERC4626Component::ComponentState<ContractState>,
            to: ContractAddress,
            assets: u256,
        ) {
            let asset_storage = self.get_contract().external_storage.read();
            let asset_dispatcher = IERC20Dispatcher { contract_address: self.ERC4626_asset.read() };
            assert(
                asset_dispatcher.transfer_from(asset_storage, to, assets),
                ERC4626Component::Errors::TOKEN_TRANSFER_FAILED,
            );
        }

        fn get_total_assets(self: @ERC4626Component::ComponentState<ContractState>) -> u256 {
            let asset_storage = self.get_contract().external_storage.read();
            let asset_dispatcher = IERC20Dispatcher { contract_address: self.ERC4626_asset.read() };
            asset_dispatcher.balance_of(asset_storage)
        }
    }
}

#[starknet::contract]
#[with_components(ERC20, ERC4626)]
pub mod ERC4626OffsetMock {
    use openzeppelin_token::erc20::extensions::erc4626::{
        ERC4626DefaultNoFees, ERC4626DefaultNoLimits, ERC4626EmptyHooks,
        ERC4626SelfAssetsManagement,
    };
    use openzeppelin_token::erc20::{DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    // ERC4626
    #[abi(embed_v0)]
    impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
    // ERC4626MetadataImpl is a custom impl of IERC20Metadata
    #[abi(embed_v0)]
    impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    pub impl OffsetConfig of ERC4626Component::ImmutableConfig {
        const UNDERLYING_DECIMALS: u8 = ERC4626Component::DEFAULT_UNDERLYING_DECIMALS;
        const DECIMALS_OFFSET: u8 = 1;
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        underlying_asset: ContractAddress,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
        self.erc4626.initializer(underlying_asset);
    }
}

#[starknet::contract]
#[with_components(ERC20, ERC4626)]
pub mod ERC4626LimitsMock {
    use openzeppelin_token::erc20::extensions::erc4626::{
        ERC4626DefaultNoFees, ERC4626EmptyHooks, ERC4626SelfAssetsManagement,
    };
    use openzeppelin_token::erc20::{DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    // ERC4626
    #[abi(embed_v0)]
    impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
    // ERC4626MetadataImpl is a custom impl of IERC20Metadata
    #[abi(embed_v0)]
    impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    pub impl OffsetConfig of ERC4626Component::ImmutableConfig {
        const UNDERLYING_DECIMALS: u8 = ERC4626Component::DEFAULT_UNDERLYING_DECIMALS;
        const DECIMALS_OFFSET: u8 = 1;
    }

    pub const CUSTOM_LIMIT: u256 = 100_000_000_000_000_000_000;

    impl ERC4626LimitsImpl of ERC4626Component::LimitConfigTrait<ContractState> {
        fn deposit_limit(
            self: @ERC4626Component::ComponentState<ContractState>, receiver: ContractAddress,
        ) -> Option<u256> {
            Option::Some(CUSTOM_LIMIT)
        }

        fn mint_limit(
            self: @ERC4626Component::ComponentState<ContractState>, receiver: ContractAddress,
        ) -> Option<u256> {
            Option::Some(CUSTOM_LIMIT)
        }

        fn withdraw_limit(
            self: @ERC4626Component::ComponentState<ContractState>, owner: ContractAddress,
        ) -> Option<u256> {
            Option::Some(CUSTOM_LIMIT)
        }

        fn redeem_limit(
            self: @ERC4626Component::ComponentState<ContractState>, owner: ContractAddress,
        ) -> Option<u256> {
            Option::Some(CUSTOM_LIMIT)
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        underlying_asset: ContractAddress,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
        self.erc4626.initializer(underlying_asset);
    }
}

/// The mock contract charges fees in terms of assets, not shares.
/// This means that the fees are calculated based on the amount of assets that are being deposited
/// or withdrawn, and not based on the amount of shares that are being minted or redeemed.
/// This is an opinionated design decision for the purpose of testing.
/// DO NOT USE IN PRODUCTION
#[starknet::contract]
#[with_components(ERC20, ERC4626)]
pub mod ERC4626AssetsFeesMock {
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc20::extensions::erc4626::ERC4626Component::{Fee, FeeConfigTrait};
    use openzeppelin_token::erc20::extensions::erc4626::{
        DefaultConfig, ERC4626DefaultNoLimits, ERC4626SelfAssetsManagement,
    };
    use openzeppelin_token::erc20::{DefaultConfig as ERC20DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{fee_on_raw, fee_on_total};

    // ERC4626
    #[abi(embed_v0)]
    impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
    // ERC4626MetadataImpl is a custom impl of IERC20Metadata
    #[abi(embed_v0)]
    impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[storage]
    pub struct Storage {
        pub entry_fee_basis_point_value: u256,
        pub entry_fee_recipient: ContractAddress,
        pub exit_fee_basis_point_value: u256,
        pub exit_fee_recipient: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        underlying_asset: ContractAddress,
        initial_supply: u256,
        recipient: ContractAddress,
        entry_fee: u256,
        entry_treasury: ContractAddress,
        exit_fee: u256,
        exit_treasury: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
        self.erc4626.initializer(underlying_asset);

        self.entry_fee_basis_point_value.write(entry_fee);
        self.entry_fee_recipient.write(entry_treasury);
        self.exit_fee_basis_point_value.write(exit_fee);
        self.exit_fee_recipient.write(exit_treasury);
    }

    /// Hooks
    impl ERC4626HooksImpl of ERC4626Component::ERC4626HooksTrait<ContractState> {
        fn after_deposit(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let fee = fee
                .unwrap_or_else(
                    || panic!("ERC4626AssetsFeesMock expects fee in after_deposit to not be None"),
                );
            let fee = match fee {
                Fee::Assets(fee) => fee,
                Fee::Shares(_) => panic!(
                    "ERC4626AssetsFeesMock expects fee in after_deposit to be of Assets type",
                ),
            };
            // Validate fee value
            let contract_state = self.get_contract();
            let entry_basis_points = contract_state.entry_fee_basis_point_value.read();
            let calculated_fee = fee_on_total(assets, entry_basis_points);
            assert!(fee == calculated_fee, "ERC4626AssetsFeesMock: incorrect fee");

            // Transfer assets fee to fee recipient
            if fee > 0 {
                let fee_recipient = contract_state.entry_fee_recipient.read();
                assert!(
                    fee_recipient != starknet::get_contract_address(),
                    "ERC4626AssetsFeesMock: cannot be fee recipient",
                );
                let asset_address = contract_state.asset();
                let asset_dispatcher = IERC20Dispatcher { contract_address: asset_address };
                assert(asset_dispatcher.transfer(fee_recipient, fee), 'Fee transfer failed');
            }
        }

        fn before_withdraw(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let fee = fee
                .unwrap_or_else(
                    || panic!(
                        "ERC4626AssetsFeesMock expects fee in before_withdraw to not be None",
                    ),
                );
            let fee = match fee {
                Fee::Assets(fee) => fee,
                Fee::Shares(_) => panic!(
                    "ERC4626AssetsFeesMock expects fee in before_withdraw to be of Assets type",
                ),
            };
            // Validate fee value
            let contract_state = self.get_contract();
            let exit_basis_points = contract_state.exit_fee_basis_point_value.read();
            let calculated_fee = fee_on_raw(assets, exit_basis_points);
            assert!(fee == calculated_fee, "ERC4626AssetsFeesMock: incorrect fee");

            // Transfer assets fee to fee recipient
            if fee > 0 {
                let fee_recipient = contract_state.exit_fee_recipient.read();
                assert!(
                    fee_recipient != starknet::get_contract_address(),
                    "ERC4626AssetsFeesMock: cannot be fee recipient",
                );
                let asset_address = contract_state.asset();
                let asset_dispatcher = IERC20Dispatcher { contract_address: asset_address };
                assert(asset_dispatcher.transfer(fee_recipient, fee), 'Fee transfer failed');
            }
        }
    }

    /// Calculate fees
    impl FeeConfigImpl of FeeConfigTrait<ContractState> {
        fn calculate_deposit_fee(
            self: @ERC4626Component::ComponentState<ContractState>, assets: u256, shares: u256,
        ) -> Option<Fee> {
            let contract_state = self.get_contract();
            let fee = fee_on_total(assets, contract_state.entry_fee_basis_point_value.read());
            Option::Some(Fee::Assets(fee))
        }

        fn calculate_mint_fee(
            self: @ERC4626Component::ComponentState<ContractState>, assets: u256, shares: u256,
        ) -> Option<Fee> {
            let contract_state = self.get_contract();
            let fee = fee_on_raw(assets, contract_state.entry_fee_basis_point_value.read());
            Option::Some(Fee::Assets(fee))
        }

        fn calculate_withdraw_fee(
            self: @ERC4626Component::ComponentState<ContractState>, assets: u256, shares: u256,
        ) -> Option<Fee> {
            let contract_state = self.get_contract();
            let fee = fee_on_raw(assets, contract_state.exit_fee_basis_point_value.read());
            Option::Some(Fee::Assets(fee))
        }

        fn calculate_redeem_fee(
            self: @ERC4626Component::ComponentState<ContractState>, assets: u256, shares: u256,
        ) -> Option<Fee> {
            let contract_state = self.get_contract();
            let fee = fee_on_total(assets, contract_state.exit_fee_basis_point_value.read());
            Option::Some(Fee::Assets(fee))
        }
    }
}

/// This mock contract charges fees in terms of shares, not assets.
/// DO NOT USE IN PRODUCTION
#[starknet::contract]
#[with_components(ERC20, ERC4626)]
pub mod ERC4626SharesFeesMock {
    use openzeppelin_token::erc20::extensions::erc4626::ERC4626Component::{Fee, FeeConfigTrait};
    use openzeppelin_token::erc20::extensions::erc4626::{
        DefaultConfig, ERC4626DefaultNoLimits, ERC4626SelfAssetsManagement,
    };
    use openzeppelin_token::erc20::{DefaultConfig as ERC20DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{fee_on_raw, fee_on_total};

    // ERC4626
    #[abi(embed_v0)]
    impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
    // ERC4626MetadataImpl is a custom impl of IERC20Metadata
    #[abi(embed_v0)]
    impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[storage]
    pub struct Storage {
        pub entry_fee_basis_point_value: u256,
        pub entry_fee_recipient: ContractAddress,
        pub exit_fee_basis_point_value: u256,
        pub exit_fee_recipient: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        underlying_asset: ContractAddress,
        initial_supply: u256,
        recipient: ContractAddress,
        entry_fee: u256,
        entry_treasury: ContractAddress,
        exit_fee: u256,
        exit_treasury: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
        self.erc4626.initializer(underlying_asset);

        self.entry_fee_basis_point_value.write(entry_fee);
        self.entry_fee_recipient.write(entry_treasury);
        self.exit_fee_basis_point_value.write(exit_fee);
        self.exit_fee_recipient.write(exit_treasury);
    }

    /// Hooks
    impl ERC4626HooksImpl of ERC4626Component::ERC4626HooksTrait<ContractState> {
        fn after_deposit(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let fee = fee
                .unwrap_or_else(
                    || panic!("ERC4626FeesSharesMock expects fee in after_deposit to not be None"),
                );
            let fee = match fee {
                Fee::Shares(fee) => fee,
                Fee::Assets(_) => panic!(
                    "ERC4626FeesSharesMock expects fee in after_deposit to be of Shares type",
                ),
            };
            // Validate fee value
            let mut contract_state = self.get_contract_mut();
            let entry_basis_points = contract_state.entry_fee_basis_point_value.read();
            let calculated_fee = fee_on_raw(shares, entry_basis_points);
            assert!(fee == calculated_fee, "ERC4626FeesSharesMock: incorrect fee");

            // Mint shares fee to fee recipient
            if fee > 0 {
                let fee_recipient = contract_state.entry_fee_recipient.read();
                contract_state.erc20.mint(fee_recipient, fee);
            }
        }

        fn before_withdraw(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let fee = fee
                .unwrap_or_else(
                    || panic!(
                        "ERC4626FeesSharesMock expects fee in before_withdraw to not be None",
                    ),
                );
            let fee = match fee {
                Fee::Shares(fee) => fee,
                Fee::Assets(_) => panic!(
                    "ERC4626FeesSharesMock expects fee in before_withdraw to be of Shares type",
                ),
            };
            // Validate fee value
            let mut contract_state = self.get_contract_mut();
            let exit_basis_points = contract_state.exit_fee_basis_point_value.read();
            let calculated_fee = fee_on_raw(assets, exit_basis_points);
            assert!(fee == calculated_fee, "ERC4626FeesSharesMock: incorrect fee");

            // Transfer shares fee to fee recipient
            if fee > 0 {
                let fee_recipient = contract_state.exit_fee_recipient.read();
                if caller != owner {
                    contract_state.erc20._spend_allowance(owner, caller, fee);
                }
                contract_state.erc20._transfer(owner, fee_recipient, fee);
            }
        }
    }

    /// Calculate fees
    impl FeeConfigImpl of FeeConfigTrait<ContractState> {
        fn calculate_deposit_fee(
            self: @ERC4626Component::ComponentState<ContractState>, assets: u256, shares: u256,
        ) -> Option<Fee> {
            let contract_state = self.get_contract();
            let fee = fee_on_total(shares, contract_state.entry_fee_basis_point_value.read());
            Option::Some(Fee::Shares(fee))
        }

        fn calculate_mint_fee(
            self: @ERC4626Component::ComponentState<ContractState>, assets: u256, shares: u256,
        ) -> Option<Fee> {
            let contract_state = self.get_contract();
            let fee = fee_on_raw(shares, contract_state.entry_fee_basis_point_value.read());
            Option::Some(Fee::Shares(fee))
        }

        fn calculate_withdraw_fee(
            self: @ERC4626Component::ComponentState<ContractState>, assets: u256, shares: u256,
        ) -> Option<Fee> {
            let contract_state = self.get_contract();
            let fee = fee_on_raw(shares, contract_state.exit_fee_basis_point_value.read());
            Option::Some(Fee::Shares(fee))
        }

        fn calculate_redeem_fee(
            self: @ERC4626Component::ComponentState<ContractState>, assets: u256, shares: u256,
        ) -> Option<Fee> {
            let contract_state = self.get_contract();
            let fee = fee_on_total(shares, contract_state.exit_fee_basis_point_value.read());
            Option::Some(Fee::Shares(fee))
        }
    }
}

#[starknet::contract]
#[with_components(ERC20, ERC4626)]
pub mod ERC4626MockWithHooks {
    use openzeppelin_token::erc20::extensions::erc4626::ERC4626Component::Fee;
    use openzeppelin_token::erc20::extensions::erc4626::{
        DefaultConfig, ERC4626DefaultNoFees, ERC4626DefaultNoLimits, ERC4626SelfAssetsManagement,
    };
    use openzeppelin_token::erc20::{DefaultConfig as ERC20DefaultConfig, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    // ERC4626
    #[abi(embed_v0)]
    impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
    // ERC4626MetadataImpl is a custom impl of IERC20Metadata
    #[abi(embed_v0)]
    impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BeforeDeposit: BeforeDeposit,
        AfterDeposit: AfterDeposit,
        BeforeWithdraw: BeforeWithdraw,
        AfterWithdraw: AfterWithdraw,
    }

    /// Event used to test that `before_deposit` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct BeforeDeposit {
        pub caller: ContractAddress,
        pub receiver: ContractAddress,
        pub assets: u256,
        pub shares: u256,
    }

    /// Event used to test that `after_deposit` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct AfterDeposit {
        pub caller: ContractAddress,
        pub receiver: ContractAddress,
        pub assets: u256,
        pub shares: u256,
    }

    /// Event used to test that `before_withdraw` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct BeforeWithdraw {
        pub caller: ContractAddress,
        pub receiver: ContractAddress,
        pub owner: ContractAddress,
        pub assets: u256,
        pub shares: u256,
    }

    /// Event used to test that `after_withdraw` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct AfterWithdraw {
        pub caller: ContractAddress,
        pub receiver: ContractAddress,
        pub owner: ContractAddress,
        pub assets: u256,
        pub shares: u256,
    }

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        underlying_asset: ContractAddress,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
        self.erc4626.initializer(underlying_asset);
    }

    /// Hooks
    impl ERC4626HooksImpl of ERC4626Component::ERC4626HooksTrait<ContractState> {
        fn before_deposit(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(BeforeDeposit { caller, receiver, assets, shares });
        }

        fn after_deposit(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(AfterDeposit { caller, receiver, assets, shares });
        }

        fn before_withdraw(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(BeforeWithdraw { caller, receiver, owner, assets, shares });
        }

        fn after_withdraw(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(AfterWithdraw { caller, receiver, owner, assets, shares });
        }
    }
}

//
// Fee operations
//

use openzeppelin_utils::math;
use openzeppelin_utils::math::Rounding;

const _BASIS_POINT_SCALE: u256 = 10_000;

/// Calculates the fees that should be added to an amount `assets` that does not already
/// include fees.
/// Used in IERC4626::mint and IERC4626::withdraw operations.
fn fee_on_raw(assets: u256, fee_basis_points: u256) -> u256 {
    math::u256_mul_div(assets, fee_basis_points, _BASIS_POINT_SCALE, Rounding::Ceil)
}

/// Calculates the fee part of an amount `assets` that already includes fees.
/// Used in IERC4626::deposit and IERC4626::redeem operations.
fn fee_on_total(assets: u256, fee_basis_points: u256) -> u256 {
    math::u256_mul_div(
        assets, fee_basis_points, fee_basis_points + _BASIS_POINT_SCALE, Rounding::Ceil,
    )
}
