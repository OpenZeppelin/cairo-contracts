#[starknet::component]
mod ERC721Receiver {
    use openzeppelin::introspection::src5::SRC5::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5;
    use openzeppelin::token::erc721::interface::{IERC721Receiver, IERC721ReceiverCamel};
    use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[embeddable_as(ERC721ReceiverImpl)]
    impl ERC721Receiver<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721Receiver<ComponentState<TContractState>> {
        fn on_erc721_received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> felt252 {
            IERC721_RECEIVER_ID
        }
    }

    #[embeddable_as(ERC721ReceiverCamelImpl)]
    impl ERC721ReceiverCamel<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721ReceiverCamel<ComponentState<TContractState>> {
        fn onERC721Received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) -> felt252 {
            self.on_erc721_received(operator, from, tokenId, data)
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut contract = self.get_contract_mut();
            let mut src5_component = SRC5::HasComponent::<
                TContractState
            >::get_component_mut(ref contract);
            src5_component.register_interface(IERC721_RECEIVER_ID);
        }
    }
}
