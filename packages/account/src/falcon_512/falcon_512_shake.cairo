// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/falcon_512_shake.cairo)

/// # Falcon-512 SHAKE Account
///
/// Account validating the Falcon-512 verification relation from the FALCON submission selected
/// by NIST, using SHAKE-256 hash-to-point. Its contract-specific 60-felt signature encoding
/// includes a signer-supplied polynomial-product hint that is checked on-chain to reduce
/// execution cost. This account does not claim conformance with FN-DSA/FIPS 206.
#[starknet::contract(account)]
pub mod Falcon512ShakeAccount {
    use openzeppelin_introspection::src5::SRC5Component;
    use super::super::Falcon512ShakeVerifier;
    use super::super::account::Falcon512AccountComponent;

    component!(path: Falcon512AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccountMixinImpl =
        Falcon512AccountComponent::Falcon512AccountMixinImpl<ContractState, Falcon512ShakeVerifier>;

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
        self.account.initializer::<Falcon512ShakeVerifier>(public_key);
    }
}
