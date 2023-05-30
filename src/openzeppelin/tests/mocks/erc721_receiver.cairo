const SUCCESS: felt252 = 123123;
const FAILURE: felt252 = 456456;

#[contract]
mod ERC721Receiver {
    use openzeppelin::token::erc721::interface::IERC721Receiver;
    use openzeppelin::token::erc721::interface::IERC721ReceiverCamel;
    use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
    use openzeppelin::introspection::erc165::ERC165;

    use openzeppelin::utils::serde::SpanSerde;
    use starknet::ContractAddress;
    use array::SpanTrait;

    impl ERC721ReceiverImpl of IERC721Receiver {
        fn on_erc721_received(
            operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
        ) -> u32 {
            if *data.at(0) == super::SUCCESS {
                IERC721_RECEIVER_ID
            } else {
                0
            }
        }
    }

    impl ERC721ReceiverCamelImpl of IERC721ReceiverCamel {
        fn onERC721Received(
            operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
        ) -> u32 {
            ERC721ReceiverImpl::on_erc721_received(operator, from, tokenId, data)
        }
    }

    #[constructor]
    fn constructor() {
        ERC165::register_interface(IERC721_RECEIVER_ID);
    }

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        ERC165::supports_interface(interface_id)
    }

    #[external]
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> u32 {
        ERC721ReceiverImpl::on_erc721_received(operator, from, token_id, data)
    }

    #[external]
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> u32 {
        ERC721ReceiverCamelImpl::onERC721Received(operator, from, tokenId, data)
    }
}


#[contract]
mod ERC721NonReceiver {}
