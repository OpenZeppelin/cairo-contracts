// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (token/erc1155/erc1155_receiver.cairo)

/// # ERC1155Receiver Component
///
/// The ERC1155Receiver component provides implementations for the IERC1155Receiver
/// interface. Integrating this component allows contracts to support ERC1155
/// safe transfers.
#[starknet::component]
mod ERC1155ReceiverComponent {
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::interface::IERC1155_RECEIVER_ID;
    use openzeppelin::token::erc1155::interface::{IERC1155Receiver, IERC1155ReceiverCamel};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[embeddable_as(ERC1155ReceiverImpl)]
    impl ERC1155Receiver<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC1155Receiver<ComponentState<TContractState>> {
        /// Called whenever the implementing contract receives `value` through
        /// a safe transfer. This function must return `IERC1155_RECEIVER_ID`
        /// to confirm the token transfer.
        fn on_erc1155_received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) -> felt252 {
            IERC1155_RECEIVER_ID
        }

        fn on_erc1155_batch_received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) -> felt252 {
            IERC1155_RECEIVER_ID
        }
    }

    /// Adds camelCase support for `IERC1155Receiver`.
    #[embeddable_as(ERC1155ReceiverCamelImpl)]
    impl ERC1155ReceiverCamel<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC1155ReceiverCamel<ComponentState<TContractState>> {
        fn onERC1155Received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            value: u256,
            data: Span<felt252>
        ) -> felt252 {
            IERC1155_RECEIVER_ID
        }

        fn onERC1155BatchReceived(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) -> felt252 {
            IERC1155_RECEIVER_ID
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering the IERC1155Receiver interface ID.
        /// This should be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC1155_RECEIVER_ID);
        }
    }
}
