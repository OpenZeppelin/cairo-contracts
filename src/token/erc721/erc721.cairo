// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (token/erc721/erc721.cairo)

#[starknet::component]
mod ERC721 {
    use openzeppelin::account;
    use openzeppelin::introspection::dual_src5::DualCaseSRC5;
    use openzeppelin::introspection::dual_src5::DualCaseSRC5Trait;
    use openzeppelin::introspection::src5::SRC5::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5;
    use openzeppelin::token::erc721::dual721_receiver::DualCaseERC721Receiver;
    use openzeppelin::token::erc721::dual721_receiver::DualCaseERC721ReceiverTrait;
    use openzeppelin::token::erc721::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC721_name: felt252,
        ERC721_symbol: felt252,
        ERC721_owners: LegacyMap<u256, ContractAddress>,
        ERC721_balances: LegacyMap<ContractAddress, u256>,
        ERC721_token_approvals: LegacyMap<u256, ContractAddress>,
        ERC721_operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        ERC721_token_uri: LegacyMap<u256, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        approved: ContractAddress,
        #[key]
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        #[key]
        owner: ContractAddress,
        #[key]
        operator: ContractAddress,
        approved: bool
    }

    mod Errors {
        const INVALID_TOKEN_ID: felt252 = 'ERC721: invalid token ID';
        const INVALID_ACCOUNT: felt252 = 'ERC721: invalid account';
        const UNAUTHORIZED: felt252 = 'ERC721: unauthorized caller';
        const APPROVAL_TO_OWNER: felt252 = 'ERC721: approval to owner';
        const SELF_APPROVAL: felt252 = 'ERC721: self approval';
        const INVALID_RECEIVER: felt252 = 'ERC721: invalid receiver';
        const ALREADY_MINTED: felt252 = 'ERC721: token already minted';
        const WRONG_SENDER: felt252 = 'ERC721: wrong sender';
        const SAFE_MINT_FAILED: felt252 = 'ERC721: safe mint failed';
        const SAFE_TRANSFER_FAILED: felt252 = 'ERC721: safe transfer failed';
    }

    //
    // External
    //

    #[embeddable_as(ERC721Impl)]
    impl ERC721<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721<ComponentState<TContractState>> {
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            assert(!account.is_zero(), Errors::INVALID_ACCOUNT);
            self.ERC721_balances.read(account)
        }

        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            self._owner_of(token_id)
        }

        fn get_approved(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_approvals.read(token_id)
        }

        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC721_operator_approvals.read((owner, operator))
        }

        fn approve(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || self.is_approved_for_all(owner, caller), Errors::UNAUTHORIZED
            );
            self._approve(to, token_id);
        }

        fn set_approval_for_all(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            self._set_approval_for_all(get_caller_address(), operator, approved)
        }

        fn transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id), Errors::UNAUTHORIZED
            );
            self._transfer(from, to, token_id);
        }

        fn safe_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id), Errors::UNAUTHORIZED
            );
            self._safe_transfer(from, to, token_id, data);
        }
    }

    #[embeddable_as(ERC721MetadataImpl)]
    impl ERC721Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721Metadata<ComponentState<TContractState>> {
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            self.ERC721_name.read()
        }

        fn symbol(self: @ComponentState<TContractState>) -> felt252 {
            self.ERC721_symbol.read()
        }

        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> felt252 {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_uri.read(token_id)
        }
    }

    #[embeddable_as(ERC721CamelOnlyImpl)]
    impl ERC721CamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721CamelOnly<ComponentState<TContractState>> {
        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }

        fn ownerOf(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            self.owner_of(tokenId)
        }

        fn getApproved(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            self.get_approved(tokenId)
        }

        fn isApprovedForAll(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.is_approved_for_all(owner, operator)
        }

        fn setApprovalForAll(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            self.set_approval_for_all(operator, approved)
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256
        ) {
            self.transfer_from(from, to, tokenId)
        }

        fn safeTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            self.safe_transfer_from(from, to, tokenId, data)
        }
    }

    #[embeddable_as(ERC721MetadataCamelOnlyImpl)]
    impl ERC721MetadataCamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721MetadataCamelOnly<ComponentState<TContractState>> {
        fn tokenURI(self: @ComponentState<TContractState>, tokenId: u256) -> felt252 {
            assert(self._exists(tokenId), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_uri.read(tokenId)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, name: felt252, symbol: felt252) {
            self.ERC721_name.write(name);
            self.ERC721_symbol.write(symbol);

            let mut contract = self.get_contract_mut();
            let mut src5_component = SRC5::HasComponent::<
                TContractState
            >::get_component_mut(ref contract);
            src5_component.register_interface(interface::IERC721_ID);
            src5_component.register_interface(interface::IERC721_METADATA_ID);
        }

        fn _owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            let owner = self.ERC721_owners.read(token_id);
            match owner.is_zero() {
                bool::False(()) => owner,
                bool::True(()) => panic_with_felt252(Errors::INVALID_TOKEN_ID)
            }
        }

        fn _exists(self: @ComponentState<TContractState>, token_id: u256) -> bool {
            !self.ERC721_owners.read(token_id).is_zero()
        }

        fn _is_approved_or_owner(
            self: @ComponentState<TContractState>, spender: ContractAddress, token_id: u256
        ) -> bool {
            let owner = self._owner_of(token_id);
            let is_approved_for_all = self.is_approved_for_all(owner, spender);
            owner == spender || is_approved_for_all || spender == self.get_approved(token_id)
        }

        fn _approve(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);
            assert(owner != to, Errors::APPROVAL_TO_OWNER);

            self.ERC721_token_approvals.write(token_id, to);
            self.emit(Approval { owner, approved: to, token_id });
        }

        fn _set_approval_for_all(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            operator: ContractAddress,
            approved: bool
        ) {
            assert(owner != operator, Errors::SELF_APPROVAL);
            self.ERC721_operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        fn _mint(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            assert(!self._exists(token_id), Errors::ALREADY_MINTED);

            self.ERC721_balances.write(to, self.ERC721_balances.read(to) + 1);
            self.ERC721_owners.write(token_id, to);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }

        fn _transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            let owner = self._owner_of(token_id);
            assert(from == owner, Errors::WRONG_SENDER);

            // Implicit clear approvals, no need to emit an event
            self.ERC721_token_approvals.write(token_id, Zeroable::zero());

            self.ERC721_balances.write(from, self.ERC721_balances.read(from) - 1);
            self.ERC721_balances.write(to, self.ERC721_balances.read(to) + 1);
            self.ERC721_owners.write(token_id, to);

            self.emit(Transfer { from, to, token_id });
        }

        fn _burn(ref self: ComponentState<TContractState>, token_id: u256) {
            let owner = self._owner_of(token_id);

            // Implicit clear approvals, no need to emit an event
            self.ERC721_token_approvals.write(token_id, Zeroable::zero());

            self.ERC721_balances.write(owner, self.ERC721_balances.read(owner) - 1);
            self.ERC721_owners.write(token_id, Zeroable::zero());

            self.emit(Transfer { from: owner, to: Zeroable::zero(), token_id });
        }

        fn _safe_mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            self._mint(to, token_id);
            assert(
                _check_on_erc721_received(Zeroable::zero(), to, token_id, data),
                Errors::SAFE_MINT_FAILED
            );
        }

        fn _safe_transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            self._transfer(from, to, token_id);
            assert(
                _check_on_erc721_received(from, to, token_id, data), Errors::SAFE_TRANSFER_FAILED
            );
        }

        fn _set_token_uri(
            ref self: ComponentState<TContractState>, token_id: u256, token_uri: felt252
        ) {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_uri.write(token_id, token_uri)
        }
    }

    fn _check_on_erc721_received(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5 { contract_address: to }
            .supports_interface(interface::IERC721_RECEIVER_ID)) {
            DualCaseERC721Receiver { contract_address: to }
                .on_erc721_received(
                    get_caller_address(), from, token_id, data
                ) == interface::IERC721_RECEIVER_ID
        } else {
            DualCaseSRC5 { contract_address: to }.supports_interface(account::interface::ISRC6_ID)
        }
    }
}
