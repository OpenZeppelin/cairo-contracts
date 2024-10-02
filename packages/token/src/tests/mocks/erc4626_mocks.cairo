#[starknet::contract]
pub(crate) mod ERC4626Mock {
    use crate::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use crate::erc20::extensions::erc4626::DefaultConfig;
    use crate::erc20::extensions::erc4626::ERC4626Component;
    use crate::erc20::extensions::erc4626::ERC4626Component::InternalTrait as ERC4626InternalTrait;
    use starknet::ContractAddress;

    component!(path: ERC4626Component, storage: erc4626, event: ERC4626Event);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // ERC4626
    #[abi(embed_v0)]
    impl ERC4626ComponentImpl = ERC4626Component::ERC4626Impl<ContractState>;
    // ERC4626MetadataImpl is a custom impl of IERC20Metadata
    #[abi(embed_v0)]
    impl ERC4626MetadataImpl = ERC4626Component::ERC4626MetadataImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    impl ERC4626InternalImpl = ERC4626Component::InternalImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc4626: ERC4626Component::Storage,
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC4626Event: ERC4626Component::Event,
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        underlying_asset: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc4626.initializer(underlying_asset);
    }
}
