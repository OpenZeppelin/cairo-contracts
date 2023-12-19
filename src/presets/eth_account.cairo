// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo vX.Y.Z (presets/eth_account.cairo)

/// # EthAccount Preset
///
/// OpenZeppelin's account which can change its public key and declare,
/// deploy, or call contracts, using Ethereum signing keys.
#[starknet::contract]
mod EthAccount {
    use openzeppelin::account::eth_account::EthAccountComponent;
    use openzeppelin::account::eth_account::interface::EthPublicKey;
    use openzeppelin::account::utils::secp256k1::Secp256k1PointSerde;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: EthAccountComponent, storage: eth_account, event: EthAccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Account
    #[abi(embed_v0)]
    impl SRC6Impl = EthAccountComponent::SRC6Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC6CamelOnlyImpl = EthAccountComponent::SRC6CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyImpl = EthAccountComponent::PublicKeyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyCamelImpl =
        EthAccountComponent::PublicKeyCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeclarerImpl = EthAccountComponent::DeclarerImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeployableImpl = EthAccountComponent::DeployableImpl<ContractState>;
    impl AccountInternalImpl = EthAccountComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        eth_account: EthAccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        EthAccountEvent: EthAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: EthPublicKey) {
        self.eth_account.initializer(public_key);
    }
}
