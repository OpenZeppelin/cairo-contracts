// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (token/erc721/mixins/erc721.cairo)

#[starknet::component]
mod ERC721ReceiverMixin {
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721ReceiverComponent::{ERC721ReceiverImpl, ERC721ReceiverCamelImpl};
    use openzeppelin::token::erc721::ERC721ReceiverComponent;
    use openzeppelin::token::erc721::mixins::interface;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[embeddable_as(ERC721ReceiverMixinImpl)]
    impl ERC721ReceiverMixin<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721ReceiverComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721ReceiverMixin<ComponentState<TContractState>> {
        // IERC721Receiver
        fn on_erc721_received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> felt252 {
            let erc721 = self.get_erc721();
            erc721.on_erc721_received(operator, from, token_id, data)
        }

        // IERC721ReceiverCamel
        fn onERC721Received(
            self: @ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) -> felt252 {
            let erc721 = self.get_erc721();
            erc721.onERC721Received(operator, from, tokenId, data)
        }

        // ISRC5
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            let contract = self.get_contract();
            let src5 = SRC5Component::HasComponent::<TContractState>::get_component(contract);
            src5.supports_interface(interface_id)
        }
    }

    #[generate_trait]
    impl GetERC721Impl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721ReceiverComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetERC721Trait<TContractState> {
        fn get_erc721(
            self: @ComponentState<TContractState>
        ) -> @ERC721ReceiverComponent::ComponentState::<TContractState> {
            let contract = self.get_contract();
            ERC721ReceiverComponent::HasComponent::<TContractState>::get_component(contract)
        }
    }
}
