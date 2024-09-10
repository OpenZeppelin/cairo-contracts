// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.16.0 (token/erc20/extensions/erc20_permit/erc20_permit.cairo)

use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::StructHash;
use starknet::ContractAddress;

/// # ERC20Permit Component
///
/// The ERC20Permit component implements the EIP-2612 standard, facilitating token approvals via
/// off-chain signatures. This approach allows token holders to delegate their approval to spend
/// tokens without executing an on-chain transaction, reducing gas costs and enhancing usability.
/// The message signed and the signature must follow the SNIP-12 standard for hashing and signing
/// typed structured data.
///
/// To safeguard against replay attacks and ensure the uniqueness of each approval via `permit`, the
/// data signed includes:
///   - The address of the owner
///   - The parameters specified in the `approve` function (spender and amount)
///   - The address of the token contract itself
///   - A nonce, which must be unique for each operation, incrementing after each use to prevent
///   reuse of the signature - The chain ID, which protects against cross-chain replay attacks
///
/// EIP-2612: https://eips.ethereum.org/EIPS/eip-2612
/// SNIP-12:  https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-12.md
#[starknet::component]
pub mod ERC20PermitComponent {
    use crate::erc20::ERC20Component::InternalTrait;
    use crate::erc20::ERC20Component;
    use crate::erc20::extensions::erc20_permit::interface::IERC20Permit;
    use openzeppelin_account::dual_account::{DualCaseAccount, DualCaseAccountTrait};
    use openzeppelin_utils::cryptography::interface::{INonces, ISNIP12Metadata};
    use openzeppelin_utils::cryptography::snip12::{
        StructHash, OffchainMessageHash, SNIP12Metadata, StarknetDomain
    };
    use openzeppelin_utils::nonces::NoncesComponent::InternalTrait as NoncesInternalTrait;
    use openzeppelin_utils::nonces::NoncesComponent;
    use starknet::{ContractAddress, get_block_timestamp, get_contract_address, get_tx_info};

    #[storage]
    struct Storage {}

    pub mod Errors {
        pub const EXPIRED_SIGNATURE: felt252 = 'ERC20Permit: expired signature';
        pub const INVALID_SIGNATURE: felt252 = 'ERC20Permit: invalid signature';
    }

    //
    // External
    //

    #[embeddable_as(ERC20PermitImpl)]
    impl ERC20Permit<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        impl Nonces: NoncesComponent::HasComponent<TContractState>,
        impl Metadata: SNIP12Metadata,
        +Drop<TContractState>
    > of IERC20Permit<ComponentState<TContractState>> {
        /// Sets the allowance of the `spender` over `owner`'s tokens after validating the signature
        /// generated off-chain and signed by the `owner`.
        ///
        /// Requirements:
        ///
        /// - `owner` is a deployed account contract.
        /// - `spender` is not the zero address.
        /// - `deadline` is a timestamp in the future.
        /// - `signature` is a valid signature that can be validated with a call to `owner` account.
        /// - `signature` must use the current nonce of the `owner`.
        ///
        /// Emits an `Approval` event.
        fn permit(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            deadline: u64,
            signature: Array<felt252>
        ) {
            assert(get_block_timestamp() <= deadline, Errors::EXPIRED_SIGNATURE);

            // Get current nonce and increment it
            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            let nonce = nonces_component.use_nonce(owner);

            // Compute hash for permit
            let permit = super::Permit {
                token: get_contract_address(), spender, amount, nonce, deadline
            };
            let permit_hash = permit.get_message_hash(owner);

            // Make a call to the account to validate permit signature
            let is_valid_sig_felt = DualCaseAccount { contract_address: owner }
                .is_valid_signature(permit_hash, signature);

            // Check the response is either 'VALID' or True (for backwards compatibility)
            let is_valid_sig = is_valid_sig_felt == starknet::VALIDATED || is_valid_sig_felt == 1;
            assert(is_valid_sig, Errors::INVALID_SIGNATURE);

            // Approve
            let mut erc20_component = get_dep_component_mut!(ref self, ERC20);
            erc20_component._approve(owner, spender, amount);
        }

        /// Returns the current nonce of the `owner`. A nonce value must be
        /// included whenever a signature for `permit` is generated.
        fn nonces(self: @ComponentState<TContractState>, owner: ContractAddress) -> felt252 {
            let nonces_component = get_dep_component!(self, Nonces);
            nonces_component.nonces(owner)
        }

        /// Returns the domain separator used in generating a message hash for `permit` signature.
        /// The domain hashing logic follows SNIP-12 standard.
        fn DOMAIN_SEPARATOR(self: @ComponentState<TContractState>) -> felt252 {
            let domain = StarknetDomain {
                name: Metadata::name(),
                version: Metadata::version(),
                chain_id: get_tx_info().unbox().chain_id,
                revision: 1
            };
            domain.hash_struct()
        }
    }

    #[embeddable_as(SNIP12MetadataExternalImpl)]
    impl SNIP12MetadataExternal<
        TContractState, +HasComponent<TContractState>, impl Metadata: SNIP12Metadata
    > of ISNIP12Metadata<ComponentState<TContractState>> {
        /// Returns domain name and version used for generating a message hash for permit signature.
        fn snip12_metadata(self: @ComponentState<TContractState>) -> (felt252, felt252) {
            (Metadata::name(), Metadata::version())
        }
    }
}

//
// Hash helpers
//

#[derive(Copy, Drop, Hash)]
pub struct Permit {
    pub token: ContractAddress,
    pub spender: ContractAddress,
    pub amount: u256,
    pub nonce: felt252,
    pub deadline: u64,
}

// Since there's no u64 type in SNIP-12, the type used for `deadline` parameter is u128
// selector!(
//     "\"Permit\"(
//         \"token\":\"ContractAddress\",
//         \"spender\":\"ContractAddress\",
//         \"amount\":\"u256\",
//         \"nonce\":\"felt\",
//         \"deadline\":\"u128\"
//     )"
// );
pub const PERMIT_TYPE_HASH: felt252 =
    0x2a8eb238e7cde741a544afcc79fe945d4292b089875fd068633854927fd5a96;

impl StructHashImpl of StructHash<Permit> {
    fn hash_struct(self: @Permit) -> felt252 {
        PoseidonTrait::new().update_with(PERMIT_TYPE_HASH).update_with(*self).finalize()
    }
}
