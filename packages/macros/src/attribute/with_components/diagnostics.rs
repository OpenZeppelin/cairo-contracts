//! List of errors and warnings for the with_components attribute.

#[allow(non_snake_case)]
pub mod errors {
    /// Error when the module has no body.
    pub const NO_BODY: &str = "Contract module must have a body.\n";

    /// Error when the component is invalid.
    pub fn INVALID_COMPONENT(short_name: &str) -> String {
        format!("{short_name} is not in the list of allowed components.\n")
    }
    /// Error when the module has no `#[starknet::contract]` attribute.
    pub fn NO_CONTRACT_ATTRIBUTE(contract_attribute: &str) -> String {
        format!("Contract module must have the `#[{contract_attribute}]` attribute.\n")
    }

    /// Error when multiple AccessControl components are used together.
    pub fn MULTIPLE_ACCESS_CONTROL_COMPONENTS(components: &str) -> String {
        format!("Only one AccessControl component can be used. Found: [{components}].\n")
    }
}

#[allow(non_snake_case)]
pub mod warnings {
    use indoc::{formatdoc, indoc};

    /// Warning when the initializers for the components are missing.
    pub fn INITIALIZERS_MISSING(components: &str) -> String {
        formatdoc!(
            "It looks like the initializers for the following components are missing:

            {components}

            This may lead to unexpected behavior.
            We recommend adding the corresponding initializer calls to the constructor.
            "
        )
    }

    /// Warning when the component has no immutable config.
    pub fn IMMUTABLE_CONFIG_MISSING(short_name: &str, default_config_path: &str) -> String {
        formatdoc!(
            "The {} component requires an ImmutableConfig implementation in scope and
            it looks like it is missing.

            You can use the default implementation by importing it:

            `use {};`
            ",
            short_name,
            default_config_path
        )
    }

    /// Warning when the Vesting component is missing an implementation of the VestingScheduleTrait.
    pub const VESTING_SCHEDULE_IMPL_MISSING: &str = indoc! {
        "The Vesting component requires an implementation of the VestingScheduleTrait in scope and
        it looks like it is missing.

        You can use the LinearVestingSchedule implementation by importing it:

        `use openzeppelin_finance::vesting::LinearVestingSchedule;`
        "
    };

    /// Warning when the Initializable component is not used.
    pub const INITIALIZABLE_NOT_USED: &str = indoc! {
        "It looks like the `self.initializable.initialize()` function is not used in the contract. If
        this is intentional, you may consider removing the Initializable component.
        "
    };

    /// Warning when the Pausable component is not used.
    pub const PAUSABLE_NOT_USED: &str = indoc! {
        "It looks like the `self.pausable.pause()` and `self.pausable.unpause()` functions are not used in the contract. If
        this is intentional, you may consider removing the Pausable component.
        "
    };

    /// Warning when the ERC20 component is missing an implementation of the ERC20HooksTrait.
    pub const ERC20_HOOKS_IMPL_MISSING: &str = indoc! {
        "The ERC20 component requires an implementation of the ERC20HooksTrait in scope and
        it looks like it is missing.

        You can use the ERC20HooksEmptyImpl implementation by importing it:

        `use openzeppelin_token::erc20::ERC20HooksEmptyImpl;`
        "
    };

    /// Warning when the ERC721 component is missing an implementation of the ERC721HooksTrait.
    pub const ERC721_HOOKS_IMPL_MISSING: &str = indoc! {
        "The ERC721 component requires an implementation of the ERC721HooksTrait in scope and
        it looks like it is missing.

        You can use the ERC721HooksEmptyImpl implementation by importing it:

        `use openzeppelin_token::erc721::ERC721HooksEmptyImpl;`
        "
    };

    /// Warning when the ERC1155 component is missing an implementation of the ERC1155HooksTrait.
    pub const ERC1155_HOOKS_IMPL_MISSING: &str = indoc! {
        "The ERC1155 component requires an implementation of the ERC1155HooksTrait in scope and
        it looks like it is missing.

        You can use the ERC1155HooksEmptyImpl implementation by importing it:

        `use openzeppelin_token::erc1155::ERC1155HooksEmptyImpl;`
        "
    };

    /// Warning when the Upgradeable component is not used.
    pub const UPGRADEABLE_NOT_USED: &str = indoc! {
        "It looks like the `self.upgradeable.upgrade(new_class_hash)` function is not used in the contract. If
        this is intentional, you may consider removing the Upgradeable component.
        "
    };

    /// Warning when the Votes component is missing an implementation of the SNIP12Metadata trait.
    pub const SNIP12_METADATA_IMPL_MISSING: &str = indoc! {
        "The Votes component requires an implementation of the SNIP12Metadata trait in scope and
        it looks like it is missing.
        "
    };

    /// Warning when the ERC4626 component is missing an implementation of the ERC4626HooksTrait.
    pub const ERC4626_HOOKS_IMPL_MISSING: &str = indoc! {
        "The ERC4626 component requires an implementation of the ERC4626HooksTrait in scope and
        it looks like it is missing.

        You can use the ERC4626EmptyHooks implementation by importing it:

        `use openzeppelin_token::erc20::extensions::erc4626::ERC4626EmptyHooks;`
        "
    };

    /// Warning when the ERC4626 component is missing an implementation of the FeeConfigTrait.
    pub const ERC4626_FEE_CONFIG_IMPL_MISSING: &str = indoc! {
        "The ERC4626 component requires an implementation of the FeeConfigTrait in scope and
        it looks like it is missing.

        You can use the ERC4626DefaultNoFees implementation by importing it:

        `use openzeppelin_token::erc20::extensions::erc4626::ERC4626DefaultNoFees;`
        "
    };

    /// Warning when the ERC4626 component is missing an implementation of the LimitConfigTrait.
    pub const ERC4626_LIMIT_CONFIG_IMPL_MISSING: &str = indoc! {
        "The ERC4626 component requires an implementation of the LimitConfigTrait in scope and
        it looks like it is missing.

        You can use the ERC4626DefaultNoLimits implementation by importing it:

        `use openzeppelin_token::erc20::extensions::erc4626::ERC4626DefaultNoLimits;`
        "
    };

    /// Warning when the ERC4626 component is missing an implementation of the AssetsManagementTrait.
    pub const ERC4626_ASSETS_MANAGEMENT_IMPL_MISSING: &str = indoc! {
        "The ERC4626 component requires an implementation of the AssetsManagementTrait in scope and
        it looks like it is missing.

        You can use the ERC4626SelfAssetsManagement implementation by importing it:

        `use openzeppelin_token::erc20::extensions::erc4626::ERC4626SelfAssetsManagement;`
        "
    };
}
