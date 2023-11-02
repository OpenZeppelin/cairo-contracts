// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.0 (token/erc721/erc721_receiver.cairo)

/// # ERC721Receiver Component
///
/// The ERC721Receiver component provides implementations for the IERC721Receiver
/// interface. Integrating this component allows contracts to support ERC721
/// safe transfers.
#[starknet::component]
mod ERC721ReceiverComponent {
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
    use openzeppelin::token::erc721::interface::{IERC721Receiver, IERC721ReceiverCamel};
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
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721Receiver<ComponentState<TContractState>> {
        /// Called whenever the implementing contract receives `token_id` through
        /// a safe transfer. This function must return `IERC721_RECEIVER_ID`
        /// to confirm the token transfer.
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

    /// Adds camelCase support for `IERC721Receiver`.
    #[embeddable_as(ERC721ReceiverCamelImpl)]
    impl ERC721ReceiverCamel<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721ReceiverCamel<ComponentState<TContractState>> {
        fn onERC721Received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) -> felt252 {
            IERC721_RECEIVER_ID
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering the IERC721Receiver interface ID.
        /// This should be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC721_RECEIVER_ID);
        }
    }
}
