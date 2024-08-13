// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc6909/extensions/erc6909_votes.cairo)

use starknet::ContractAddress;

/// # ERC6909ContentURI Component
///
/// The ERC6909ContentURI component allows to set the contract and token ID URIs.
/// The internal function `initializer` should be used ideally in the constructor.
#[starknet::component]
pub mod ERC6909ContentURIComponent {
    use openzeppelin_token::erc6909::ERC6909Component;
    use openzeppelin_token::erc6909::interface;

    #[storage]
    struct Storage {
        ERC6909ContentURI_contract_uri: ByteArray,
    }

    #[embeddable_as(ERC6909ContentURIImpl)]
    impl ERC6909ContentURI<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>
    > of interface::IERC6909ContentURI<ComponentState<TContractState>> {
        /// Returns the contract level URI.
        fn contract_uri(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC6909ContentURI_contract_uri.read()
        }

        /// Returns the token level URI.
        fn token_uri(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            let contract_uri = self.contract_uri();
            if contract_uri.len() == 0 {
                return "";
            } else {
                return format!("{}{}", contract_uri, id);
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC6909: ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Sets the base URI.
        fn initializer(ref self: ComponentState<TContractState>, contract_uri: ByteArray) {
            self.ERC6909ContentURI_contract_uri.write(contract_uri);
        }
    }
}

