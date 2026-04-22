// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.0
// (token/src/erc6909/extensions/erc6909_metadata.cairo)

/// # ERC6909Metadata Component
///
/// The ERC6909Metadata component allows setting metadata (name, symbol, decimals) for
/// individual token IDs. Unlike ERC20, ERC6909 supports multiple token types each with
/// its own metadata.
///
/// Call the `initializer` function in your contract's constructor to register the interface.
/// Use `set_token_name`, `set_token_symbol`, and `set_token_decimals` to configure metadata
/// per token ID as needed.
#[starknet::component]
pub mod ERC6909MetadataComponent {
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_access::accesscontrol::AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin_access::accesscontrol::extensions::AccessControlDefaultAdminRulesComponent;
    use openzeppelin_access::accesscontrol::extensions::AccessControlDefaultAdminRulesComponent::InternalTrait as AccessControlDefaultAdminRulesInternalTrait;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_access::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use openzeppelin_interfaces::erc6909 as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc6909::ERC6909Component;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    /// Role for the admin responsible for managing token metadata.
    pub const METADATA_ADMIN_ROLE: felt252 = selector!("METADATA_ADMIN_ROLE");

    #[storage]
    pub struct Storage {
        ERC6909Metadata_name: Map<u256, ByteArray>,
        ERC6909Metadata_symbol: Map<u256, ByteArray>,
        ERC6909Metadata_decimals: Map<u256, u8>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        ERC6909NameUpdated: ERC6909NameUpdated,
        ERC6909SymbolUpdated: ERC6909SymbolUpdated,
        ERC6909DecimalsUpdated: ERC6909DecimalsUpdated,
    }

    /// Emitted when the name of the token of type `id` was updated to `new_name`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ERC6909NameUpdated {
        #[key]
        pub id: u256,
        pub new_name: ByteArray,
    }

    /// Emitted when the symbol for the token of type `id` was updated to `new_symbol`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ERC6909SymbolUpdated {
        #[key]
        pub id: u256,
        pub new_symbol: ByteArray,
    }

    /// Emitted when the decimals value for token of type `id` was updated to `new_decimals`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ERC6909DecimalsUpdated {
        #[key]
        pub id: u256,
        pub new_decimals: u8,
    }

    #[embeddable_as(ERC6909MetadataImpl)]
    impl ERC6909Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909Metadata<ComponentState<TContractState>> {
        /// Returns the name for the token of type `id`
        fn name(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909Metadata_name.read(id)
        }

        /// Returns the symbol for the token of type `id`
        fn symbol(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909Metadata_symbol.read(id)
        }

        /// Returns the decimals for the token of type `id`
        fn decimals(self: @ComponentState<TContractState>, id: u256) -> u8 {
            self.ERC6909Metadata_decimals.read(id)
        }
    }

    //
    // Ownable-based implementation of IERC6909MetadataAdmin
    //

    #[embeddable_as(ERC6909MetadataAdminOwnableImpl)]
    impl ERC6909MetadataAdminOwnable<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909MetadataAdmin<ComponentState<TContractState>> {
        /// Sets the name for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract owner.
        ///
        /// Emits an `ERC6909NameUpdated` event.
        fn set_token_name(ref self: ComponentState<TContractState>, id: u256, name: ByteArray) {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self._set_token_name(id, name)
        }

        /// Sets the symbol for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract owner.
        ///
        /// Emits an `ERC6909SymbolUpdated` event.
        fn set_token_symbol(ref self: ComponentState<TContractState>, id: u256, symbol: ByteArray) {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self._set_token_symbol(id, symbol)
        }

        /// Sets the decimals for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract owner.
        ///
        /// Emits an `ERC6909DecimalsUpdated` event.
        fn set_token_decimals(ref self: ComponentState<TContractState>, id: u256, decimals: u8) {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self._set_token_decimals(id, decimals)
        }
    }

    //
    // AccessControl-based implementation of IERC6909MetadataAdmin
    //

    #[embeddable_as(ERC6909MetadataAdminAccessControlImpl)]
    impl ERC6909MetadataAdminAccessControl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909MetadataAdmin<ComponentState<TContractState>> {
        /// Sets the name for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller must have `METADATA_ADMIN_ROLE` role.
        ///
        /// Emits an `ERC6909NameUpdated` event.
        fn set_token_name(ref self: ComponentState<TContractState>, id: u256, name: ByteArray) {
            get_dep_component!(@self, AccessControl).assert_only_role(METADATA_ADMIN_ROLE);
            self._set_token_name(id, name)
        }

        /// Sets the symbol for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller must have `METADATA_ADMIN_ROLE` role.
        ///
        /// Emits an `ERC6909SymbolUpdated` event.
        fn set_token_symbol(ref self: ComponentState<TContractState>, id: u256, symbol: ByteArray) {
            get_dep_component!(@self, AccessControl).assert_only_role(METADATA_ADMIN_ROLE);
            self._set_token_symbol(id, symbol)
        }

        /// Sets the decimals for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller must have `METADATA_ADMIN_ROLE` role.
        ///
        /// Emits an `ERC6909DecimalsUpdated` event.
        fn set_token_decimals(ref self: ComponentState<TContractState>, id: u256, decimals: u8) {
            get_dep_component!(@self, AccessControl).assert_only_role(METADATA_ADMIN_ROLE);
            self._set_token_decimals(id, decimals)
        }
    }

    //
    // AccessControlDefaultAdminRules-based implementation of IERC6909MetadataAdmin
    //

    #[embeddable_as(ERC6909MetadataAdminAccessControlDefaultAdminRulesImpl)]
    impl ERC6909MetadataAdminAccessControlDefaultAdminRules<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +AccessControlDefaultAdminRulesComponent::ImmutableConfig,
        +SRC5Component::HasComponent<TContractState>,
        impl AccessControlDAR: AccessControlDefaultAdminRulesComponent::HasComponent<
            TContractState,
        >,
        +Drop<TContractState>,
    > of interface::IERC6909MetadataAdmin<ComponentState<TContractState>> {
        /// Sets the name for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller must have `METADATA_ADMIN_ROLE` role.
        ///
        /// Emits an `ERC6909NameUpdated` event.
        fn set_token_name(ref self: ComponentState<TContractState>, id: u256, name: ByteArray) {
            get_dep_component!(@self, AccessControlDAR).assert_only_role(METADATA_ADMIN_ROLE);
            self._set_token_name(id, name)
        }

        /// Sets the symbol for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller must have `METADATA_ADMIN_ROLE` role.
        ///
        /// Emits an `ERC6909SymbolUpdated` event.
        fn set_token_symbol(ref self: ComponentState<TContractState>, id: u256, symbol: ByteArray) {
            get_dep_component!(@self, AccessControlDAR).assert_only_role(METADATA_ADMIN_ROLE);
            self._set_token_symbol(id, symbol)
        }

        /// Sets the decimals for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller must have `METADATA_ADMIN_ROLE` role.
        ///
        /// Emits an `ERC6909DecimalsUpdated` event.
        fn set_token_decimals(ref self: ComponentState<TContractState>, id: u256, decimals: u8) {
            get_dep_component!(@self, AccessControlDAR).assert_only_role(METADATA_ADMIN_ROLE);
            self._set_token_decimals(id, decimals)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by declaring support for the `IERC6909Metadata`
        /// interface id.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC6909_METADATA_ID);
        }

        /// Sets the token name.
        fn _set_token_name(ref self: ComponentState<TContractState>, id: u256, name: ByteArray) {
            self.ERC6909Metadata_name.write(id, name.clone());
            self.emit(ERC6909NameUpdated { id, new_name: name })
        }

        /// Sets the token symbol.
        fn _set_token_symbol(
            ref self: ComponentState<TContractState>, id: u256, symbol: ByteArray,
        ) {
            self.ERC6909Metadata_symbol.write(id, symbol.clone());
            self.emit(ERC6909SymbolUpdated { id, new_symbol: symbol });
        }

        /// Sets the token decimals.
        fn _set_token_decimals(ref self: ComponentState<TContractState>, id: u256, decimals: u8) {
            self.ERC6909Metadata_decimals.write(id, decimals);
            self.emit(ERC6909DecimalsUpdated { id, new_decimals: decimals })
        }
    }
}
