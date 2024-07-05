#[starknet::contract]
pub(crate) mod DualCaseERC6909MetadataMock {
    use openzeppelin::token::erc6909::extensions::ERC6909MetadataComponent::InternalTrait as ERC6909MetadataInternalTrait;
    use openzeppelin::token::erc6909::extensions::ERC6909MetadataComponent;
    use openzeppelin::token::erc6909::{ERC6909Component, ERC6909HooksEmptyImpl};
    use starknet::ContractAddress;
    component!(
        path: ERC6909MetadataComponent, storage: erc6909_metadata, event: ERC6909MetadataEvent
    );
    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);

    // ERC6909Metadata
    #[abi(embed_v0)]
    impl ERC6909MetadataComponentImpl =
        ERC6909MetadataComponent::ERC6909MetadataImpl<ContractState>;

    // ERC6909Mixin
    #[abi(embed_v0)]
    impl ERC6909MixinImpl = ERC6909Component::ERC6909MixinImpl<ContractState>;
    impl InternalImpl = ERC6909Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909_metadata: ERC6909MetadataComponent::Storage,
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909MetadataEvent: ERC6909MetadataComponent::Event,
        #[flat]
        ERC6909Event: ERC6909Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256) {
        self.erc6909.mint(receiver, id, amount);
    }
}
