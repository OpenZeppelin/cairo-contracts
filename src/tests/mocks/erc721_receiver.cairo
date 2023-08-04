const SUCCESS: felt252 = 123123;
const FAILURE: felt252 = 456456;

#[starknet::contract]
mod ERC721Receiver {
    use array::SpanTrait;
    use openzeppelin::introspection::interface::ISRC5;
    use openzeppelin::introspection::interface::ISRC5Camel;
    use openzeppelin::introspection::src5::SRC5;
    use openzeppelin::token::erc721::interface::IERC721Receiver;
    use openzeppelin::token::erc721::interface::IERC721ReceiverCamel;
    use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {
        let mut unsafe_state = SRC5::unsafe_new_contract_state();
        SRC5::InternalImpl::register_interface(ref unsafe_state, IERC721_RECEIVER_ID);
    }

    impl ISRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            let unsafe_state = SRC5::unsafe_new_contract_state();
            SRC5::SRC5Impl::supports_interface(@unsafe_state, interface_id)
        }
    }

    impl ISRC5CamelImpl of ISRC5Camel<ContractState> {
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            let unsafe_state = SRC5::unsafe_new_contract_state();
            SRC5::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
        }
    }

    impl ERC721ReceiverImpl of IERC721Receiver<ContractState> {
        fn on_erc721_received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> felt252 {
            if *data.at(0) == super::SUCCESS {
                IERC721_RECEIVER_ID
            } else {
                0
            }
        }
    }

    impl ERC721ReceiverCamelImpl of IERC721ReceiverCamel<ContractState> {
        fn onERC721Received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) -> felt252 {
            ERC721ReceiverImpl::on_erc721_received(self, operator, from, tokenId, data)
        }
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        ISRC5Impl::supports_interface(self, interface_id)
    }

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        ISRC5CamelImpl::supportsInterface(self, interfaceId)
    }

    #[external(v0)]
    fn on_erc721_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252 {
        ERC721ReceiverImpl::on_erc721_received(self, operator, from, token_id, data)
    }

    #[external(v0)]
    fn onERC721Received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252 {
        ERC721ReceiverCamelImpl::onERC721Received(self, operator, from, tokenId, data)
    }
}
