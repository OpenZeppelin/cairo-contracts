#[starknet::contract]
pub(crate) mod DualCaseERC6909ContentURIMock {
    use openzeppelin::token::erc6909::extensions::ERC6909ContentURIComponent;
    use openzeppelin::token::erc6909::{ERC6909Component, ERC6909HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(
        path: ERC6909ContentURIComponent,
        storage: erc6909_content_uri,
        event: ERC6909ContentURIEvent
    );
    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);

    // ERC6909ContentURI
    #[abi(embed_v0)]
    impl ERC6909ContentURIComponentImpl =
        ERC6909ContentURIComponent::ERC6909ContentURIImpl<ContractState>;

    // ERC6909Mixin
    #[abi(embed_v0)]
    impl ERC6909MixinImpl = ERC6909Component::ERC6909MixinImpl<ContractState>;

    impl ERC6909InternalImpl = ERC6909Component::InternalImpl<ContractState>;
    impl ERC6909ContentURIInternalImpl = ERC6909ContentURIComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909_content_uri: ERC6909ContentURIComponent::Storage,
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909ContentURIEvent: ERC6909ContentURIComponent::Event,
        #[flat]
        ERC6909Event: ERC6909Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256, uri: ByteArray
    ) {
        self.erc6909.mint(receiver, id, amount);
        self.erc6909_content_uri.initializer(uri);
    }
}
