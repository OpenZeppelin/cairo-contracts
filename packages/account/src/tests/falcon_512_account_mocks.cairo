#[starknet::contract(account)]
pub mod Falcon512ShakeAccountMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use crate::falcon_512::Falcon512ShakeVerifier;
    use crate::falcon_512::account::Falcon512AccountComponent;

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

    #[constructor]
    pub fn constructor(ref self: ContractState, public_key: Array<felt252>) {
        self.account.initializer::<Falcon512ShakeVerifier>(public_key);
    }
}

#[starknet::contract(account)]
pub mod Falcon512ShakeDirectAccountMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use crate::falcon_512::Falcon512ShakeDirectVerifier;
    use crate::falcon_512::account::Falcon512AccountComponent;

    component!(path: Falcon512AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccountMixinImpl =
        Falcon512AccountComponent::Falcon512AccountMixinImpl<
            ContractState, Falcon512ShakeDirectVerifier,
        >;

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

    #[constructor]
    pub fn constructor(ref self: ContractState, public_key: Array<felt252>) {
        self.account.initializer::<Falcon512ShakeDirectVerifier>(public_key);
    }
}
