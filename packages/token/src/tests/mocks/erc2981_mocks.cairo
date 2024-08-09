#[starknet::contract]
pub(crate) mod ERC2981Mock {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::common::erc2981::{ERC2981Component, ERC2981ImmutableDefault};
    use starknet::ContractAddress;

    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC2981Impl = ERC2981Component::ERC2981Impl<ContractState>;
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        default_receiver: ContractAddress,
        default_royalty_fraction: u256
    ) {
        self.erc2981.initializer(default_receiver, default_royalty_fraction);
    }
}
