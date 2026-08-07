// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1
// (account/src/falcon_512/falcon_512_shake_direct.cairo)

/// # Falcon-512 SHAKE Direct Account
///
/// Immutable account using the legacy Falcon-512 submission algorithm's SHAKE-256
/// hash-to-point and a 31-felt signature. It recomputes the polynomial product on-chain
/// instead of accepting a signer-supplied hint. The felt encoding is specific to this
/// contract and is not a standardized FN-DSA signature format.
#[starknet::contract(account)]
pub mod Falcon512ShakeDirectAccount {
    use openzeppelin_introspection::src5::SRC5Component;
    use super::super::Falcon512ShakeDirectVerifier;
    use super::super::account::Falcon512AccountComponent;

    component!(path: Falcon512AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC6Impl =
        Falcon512AccountComponent::SRC6Impl<ContractState, Falcon512ShakeDirectVerifier>;
    #[abi(embed_v0)]
    impl DeclarerImpl =
        Falcon512AccountComponent::DeclarerImpl<ContractState, Falcon512ShakeDirectVerifier>;
    #[abi(embed_v0)]
    impl DeployableImpl =
        Falcon512AccountComponent::DeployableImpl<ContractState, Falcon512ShakeDirectVerifier>;
    #[abi(embed_v0)]
    impl PublicKeyImpl = Falcon512AccountComponent::PublicKeyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    impl AccountInternalImpl = Falcon512AccountComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub account: Falcon512AccountComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: Falcon512AccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    /// Initializes the account with a canonical 29-felt, NTT-domain public key.
    #[constructor]
    pub fn constructor(ref self: ContractState, public_key: Array<felt252>) {
        self.account.initializer::<Falcon512ShakeDirectVerifier>(public_key);
    }
}
