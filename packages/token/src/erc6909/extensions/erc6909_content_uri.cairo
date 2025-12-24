// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc6909/extensions/erc6909_content_uri.cairo)

/// # ERC6909ContentURI Component
///
/// The ERC6909ContentURI component allows to set the contract and token ID URIs.
/// The internal function `initializer` should be used ideally in the constructor.
#[starknet::component]
pub mod ERC6909ContentURIComponent {
    use openzeppelin_interfaces::erc6909 as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_token::erc6909::ERC6909Component;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        ERC6909ContentURI_contract_uri: ByteArray,
    }

    #[embeddable_as(ERC6909ContentURIImpl)]
    impl ERC6909ContentURI<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909ContentUri<ComponentState<TContractState>> {
        /// Returns the contract level URI.
        fn contract_uri(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC6909ContentURI_contract_uri.read()
        }

        /// Returns the token level URI.
        fn token_uri(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            let contract_uri = self.contract_uri();
            if contract_uri.len() == 0 {
                ""
            } else {
                format!("{}{}", contract_uri, id)
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC6909: ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by setting the contract uri and declaring support
        /// for the `IERC6909ContentUri` interface id.
        fn initializer(ref self: ComponentState<TContractState>, contract_uri: ByteArray) {
            self.ERC6909ContentURI_contract_uri.write(contract_uri);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC6909_CONTENT_URI_ID);
        }
    }
}

