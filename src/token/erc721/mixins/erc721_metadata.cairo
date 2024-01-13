// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (token/erc721/mixins/erc721.cairo)

#[starknet::component]
mod ERC721MetadataMixin {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component::{ERC721Impl, ERC721CamelOnlyImpl};
    use openzeppelin::token::erc721::ERC721Component::{ERC721MetadataImpl, ERC721MetadataCamelOnlyImpl};
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::mixins::interface;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[embeddable_as(ERC721MetadataMixinImpl)]
    impl ERC721MetadataMixin<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721MetadataMixin<ComponentState<TContractState>> {
        // IERC721
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            let erc721 = self.get_erc721();
            erc721.balance_of(account)
        }

        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            let erc721 = self.get_erc721();
            erc721.owner_of(token_id)
        }

        fn safe_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            let mut erc721 = self.get_erc721_mut();
            erc721.safe_transfer_from(from, to, token_id, data);
        }


        fn transfer_from(ref self: ComponentState<TContractState>, from: ContractAddress, to: ContractAddress, token_id: u256) {
            let mut erc721 = self.get_erc721_mut();
            erc721.transfer_from(from, to, token_id);
        }

        fn approve(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            let mut erc721 = self.get_erc721_mut();
            erc721.approve(to, token_id);
        }

        fn set_approval_for_all(ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool) {
            let mut erc721 = self.get_erc721_mut();
            erc721.set_approval_for_all(operator, approved);
        }

        fn get_approved(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            let erc721 = self.get_erc721();
            erc721.get_approved(token_id)
        }

        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            let erc721 = self.get_erc721();
            erc721.is_approved_for_all(owner, operator)
        }

        // IERC721Metadata
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            let erc721 = self.get_erc721();
            erc721.name()
        }

        fn symbol(self: @ComponentState<TContractState>) -> felt252 {
            let erc721 = self.get_erc721();
            erc721.symbol()
        }

        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> felt252 {
            let erc721 = self.get_erc721();
            erc721.token_uri(token_id)
        }

        // IERC721CamelOnly
        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            let erc721 = self.get_erc721();
            erc721.balanceOf(account)
        }

        fn ownerOf(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            let erc721 = self.get_erc721();
            erc721.ownerOf(tokenId)
        }

        fn safeTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            let mut erc721 = self.get_erc721_mut();
            erc721.safeTransferFrom(from, to, tokenId, data);
        }

        fn transferFrom(ref self: ComponentState<TContractState>, from: ContractAddress, to: ContractAddress, tokenId: u256) {
            let mut erc721 = self.get_erc721_mut();
            erc721.transferFrom(from, to, tokenId);
        }

        fn setApprovalForAll(ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool) {
            let mut erc721 = self.get_erc721_mut();
            erc721.setApprovalForAll(operator, approved);
        }

        fn getApproved(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            let erc721 = self.get_erc721();
            erc721.getApproved(tokenId)
        }

        fn isApprovedForAll(self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress) -> bool {
            let erc721 = self.get_erc721();
            erc721.isApprovedForAll(owner, operator)
        }

        // IERC721MetadataCamelOnly
        fn tokenURI(self: @ComponentState<TContractState>, tokenId: u256) -> felt252 {
            let erc721 = self.get_erc721();
            erc721.tokenURI(tokenId)
        }
    }

    #[generate_trait]
    impl GetERC721Impl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetERC721Trait<TContractState> {
        fn get_erc721(
            self: @ComponentState<TContractState>
        ) -> @ERC721Component::ComponentState::<TContractState> {
            let contract = self.get_contract();
            ERC721Component::HasComponent::<TContractState>::get_component(contract)
        }

        fn get_erc721_mut(
            ref self: ComponentState<TContractState>
        ) -> ERC721Component::ComponentState::<TContractState> {
            let mut contract = self.get_contract_mut();
            ERC721Component::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }
}
