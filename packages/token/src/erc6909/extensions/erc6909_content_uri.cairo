// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1
// (token/src/erc6909/extensions/erc6909_content_uri.cairo)

/// # ERC6909ContentURI Component
///
/// The ERC6909ContentURI component allows to set the contract and token ID URIs.
///
/// Call the `initializer` function in your contract's constructor to register the interface.
/// Use `set_contract_uri` and `set_token_uri` to set the URIs as needed.
#[starknet::component]
pub mod ERC6909ContentURIComponent {
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
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    /// Role for the admin responsible for managing the contract and token URIs.
    pub const CONTENT_URI_ADMIN_ROLE: felt252 = selector!("CONTENT_URI_ADMIN_ROLE");

    #[storage]
    pub struct Storage {
        ERC6909ContentURI_contract_uri: ByteArray,
        ERC6909ContentURI_token_uris: Map<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        ContractURIUpdated: ContractURIUpdated,
        URI: URI,
    }

    /// Emitted when the contract URI is changed.
    /// See https://eips.ethereum.org/EIPS/eip-7572[ERC-7572] for details.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ContractURIUpdated {}

    /// Emitted when the URI for a token ID is changed.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct URI {
        pub value: ByteArray,
        #[key]
        pub id: u256,
    }

    #[embeddable_as(ERC6909ContentURIImpl)]
    impl ERC6909ContentURI<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909ContentUri<ComponentState<TContractState>> {
        /// Returns the contract level URI.
        fn contract_uri(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC6909ContentURI_contract_uri.read()
        }

        /// Returns the token level URI.
        fn token_uri(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909ContentURI_token_uris.read(id)
        }
    }

    //
    // Ownable-based implementation of IERC6909ContentUriAdmin
    //

    #[embeddable_as(ERC6909ContentURIAdminOwnableImpl)]
    impl ERC6909ContentURIAdminOwnable<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909ContentUriAdmin<ComponentState<TContractState>> {
        /// Sets the contract-level URI.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract owner.
        ///
        /// Emits a `ContractURIUpdated` event.
        fn set_contract_uri(ref self: ComponentState<TContractState>, contract_uri: ByteArray) {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self._set_contract_uri(contract_uri)
        }

        /// Sets the URI for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract owner.
        ///
        /// Emits a `URI` event.
        fn set_token_uri(ref self: ComponentState<TContractState>, id: u256, token_uri: ByteArray) {
            get_dep_component!(@self, Ownable).assert_only_owner();
            self._set_token_uri(id, token_uri)
        }
    }

    //
    // AccessControl-based implementation of IERC6909ContentUriAdmin
    //

    #[embeddable_as(ERC6909ContentURIAdminAccessControlImpl)]
    impl ERC6909ContentURIAdminAccessControl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909ContentUriAdmin<ComponentState<TContractState>> {
        /// Sets the contract-level URI.
        ///
        /// Requirements:
        ///
        /// - The caller must have `CONTENT_URI_ADMIN_ROLE` role.
        ///
        /// Emits a `ContractURIUpdated` event.
        fn set_contract_uri(ref self: ComponentState<TContractState>, contract_uri: ByteArray) {
            get_dep_component!(@self, AccessControl).assert_only_role(CONTENT_URI_ADMIN_ROLE);
            self._set_contract_uri(contract_uri)
        }

        /// Sets the URI for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller must have `CONTENT_URI_ADMIN_ROLE` role.
        ///
        /// Emits a `URI` event.
        fn set_token_uri(ref self: ComponentState<TContractState>, id: u256, token_uri: ByteArray) {
            get_dep_component!(@self, AccessControl).assert_only_role(CONTENT_URI_ADMIN_ROLE);
            self._set_token_uri(id, token_uri)
        }
    }

    //
    // AccessControlDefaultAdminRules-based implementation of IERC6909ContentUriAdmin
    //

    #[embeddable_as(ERC6909ContentURIAdminAccessControlDefaultAdminRulesImpl)]
    impl ERC6909ContentURIAdminAccessControlDefaultAdminRules<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +AccessControlDefaultAdminRulesComponent::ImmutableConfig,
        +SRC5Component::HasComponent<TContractState>,
        impl AccessControlDAR: AccessControlDefaultAdminRulesComponent::HasComponent<
            TContractState,
        >,
        +Drop<TContractState>,
    > of interface::IERC6909ContentUriAdmin<ComponentState<TContractState>> {
        /// Sets the contract-level URI.
        ///
        /// Requirements:
        ///
        /// - The caller must have `CONTENT_URI_ADMIN_ROLE` role.
        ///
        /// Emits a `ContractURIUpdated` event.
        fn set_contract_uri(ref self: ComponentState<TContractState>, contract_uri: ByteArray) {
            get_dep_component!(@self, AccessControlDAR).assert_only_role(CONTENT_URI_ADMIN_ROLE);
            self._set_contract_uri(contract_uri)
        }

        /// Sets the URI for the token of type `id`.
        ///
        /// Requirements:
        ///
        /// - The caller must have `CONTENT_URI_ADMIN_ROLE` role.
        ///
        /// Emits a `URI` event.
        fn set_token_uri(ref self: ComponentState<TContractState>, id: u256, token_uri: ByteArray) {
            get_dep_component!(@self, AccessControlDAR).assert_only_role(CONTENT_URI_ADMIN_ROLE);
            self._set_token_uri(id, token_uri)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by declaring support for the `IERC6909ContentUri` interface id.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC6909_CONTENT_URI_ID);
        }

        /// Sets the contract URI.
        ///
        /// Emits a `ContractURIUpdated` event.
        fn _set_contract_uri(ref self: ComponentState<TContractState>, contract_uri: ByteArray) {
            self.ERC6909ContentURI_contract_uri.write(contract_uri);
            self.emit(ContractURIUpdated {});
        }

        /// Sets the token URI for a given token ID.
        ///
        /// Emits a `URI` event.
        fn _set_token_uri(
            ref self: ComponentState<TContractState>, id: u256, token_uri: ByteArray,
        ) {
            self.ERC6909ContentURI_token_uris.write(id, token_uri.clone());
            self.emit(URI { value: token_uri, id });
        }
    }
}
