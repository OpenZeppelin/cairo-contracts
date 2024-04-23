// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (token/erc721/erc721.cairo)

/// # ERC721 Component
///
/// The ERC721 component provides implementations for both the IERC721 interface
/// and the IERC721Metadata interface.
#[starknet::component]
mod ERC721Component {
    use openzeppelin::account;
    use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::dual721_receiver::{
        DualCaseERC721Receiver, DualCaseERC721ReceiverTrait
    };
    use openzeppelin::token::erc721::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC721_name: ByteArray,
        ERC721_symbol: ByteArray,
        ERC721_owners: LegacyMap<u256, ContractAddress>,
        ERC721_balances: LegacyMap<ContractAddress, u256>,
        ERC721_token_approvals: LegacyMap<u256, ContractAddress>,
        ERC721_operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        ERC721_base_uri: ByteArray
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll,
    }

    /// Emitted when `token_id` token is transferred from `from` to `to`.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables `approved` to manage the `token_id` token.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        approved: ContractAddress,
        #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables or disables (`approved`) `operator` to manage
    /// all of its assets.
    #[derive(Drop, PartialEq, starknet::Event)]
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
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721<ComponentState<TContractState>> {
        /// Returns the number of NFTs owned by `account`.
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            assert(!account.is_zero(), Errors::INVALID_ACCOUNT);
            self.ERC721_balances.read(account)
        }

        /// Returns the owner address of `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            self._owner_of(token_id)
        }

        /// Transfers ownership of `token_id` from `from` if `to` is either an account or `IERC721Receiver`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - Caller is either approved or the `token_id` owner.
        /// - `to` is not the zero address.
        /// - `from` is not the zero address.
        /// - `token_id` exists.
        /// - `to` is either an account contract or supports the `IERC721Receiver` interface.
        ///
        /// Emits a `Transfer` event.
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

        /// Transfers ownership of `token_id` from `from` to `to`.
        ///
        /// Requirements:
        ///
        /// - Caller is either approved or the `token_id` owner.
        /// - `to` is not the zero address.
        /// - `from` is not the zero address.
        /// - `token_id` exists.
        ///
        /// Emits a `Transfer` event.
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

        /// Change or reaffirm the approved address for an NFT.
        ///
        /// Requirements:
        ///
        /// - The caller is either an approved operator or the `token_id` owner.
        /// - `to` cannot be the token owner.
        /// - `token_id` exists.
        ///
        /// Emits an `Approval` event.
        fn approve(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || ERC721::is_approved_for_all(@self, owner, caller),
                Errors::UNAUTHORIZED
            );
            self._approve(to, token_id);
        }

        /// Enable or disable approval for `operator` to manage all of the
        /// caller's assets.
        ///
        /// Requirements:
        ///
        /// - `operator` cannot be the caller.
        ///
        /// Emits an `Approval` event.
        fn set_approval_for_all(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            self._set_approval_for_all(get_caller_address(), operator, approved)
        }

        /// Returns the address approved for `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn get_approved(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_approvals.read(token_id)
        }

        /// Query if `operator` is an authorized operator for `owner`.
        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC721_operator_approvals.read((owner, operator))
        }
    }

    #[embeddable_as(ERC721MetadataImpl)]
    impl ERC721Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721Metadata<ComponentState<TContractState>> {
        /// Returns the NFT name.
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC721_name.read()
        }

        /// Returns the NFT symbol.
        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC721_symbol.read()
        }

        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        /// If the URI is not set, the return value will be an empty ByteArray.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> ByteArray {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            let base_uri = self._base_uri();
            if base_uri.len() == 0 {
                return "";
            } else {
                return format!("{}{}", base_uri, token_id);
            }
        }
    }

    /// Adds camelCase support for `IERC721`.
    #[embeddable_as(ERC721CamelOnlyImpl)]
    impl ERC721CamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721CamelOnly<ComponentState<TContractState>> {
        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            ERC721::balance_of(self, account)
        }

        fn ownerOf(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            ERC721::owner_of(self, tokenId)
        }

        fn safeTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            ERC721::safe_transfer_from(ref self, from, to, tokenId, data)
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256
        ) {
            ERC721::transfer_from(ref self, from, to, tokenId)
        }

        fn setApprovalForAll(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            ERC721::set_approval_for_all(ref self, operator, approved)
        }

        fn getApproved(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            ERC721::get_approved(self, tokenId)
        }

        fn isApprovedForAll(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            ERC721::is_approved_for_all(self, owner, operator)
        }
    }

    /// Adds camelCase support for `IERC721Metadata`.
    #[embeddable_as(ERC721MetadataCamelOnlyImpl)]
    impl ERC721MetadataCamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721MetadataCamelOnly<ComponentState<TContractState>> {
        fn tokenURI(self: @ComponentState<TContractState>, tokenId: u256) -> ByteArray {
            ERC721Metadata::token_uri(self, tokenId)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by setting the token name, symbol, and base URI.
        /// This should only be used inside the contract's constructor.
        fn initializer(
            ref self: ComponentState<TContractState>,
            name: ByteArray,
            symbol: ByteArray,
            base_uri: ByteArray
        ) {
            self.ERC721_name.write(name);
            self.ERC721_symbol.write(symbol);
            self._set_base_uri(base_uri);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC721_ID);
            src5_component.register_interface(interface::IERC721_METADATA_ID);
        }

        /// Returns the owner address of `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn _owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            let owner = self.ERC721_owners.read(token_id);
            match owner.is_zero() {
                bool::False(()) => owner,
                bool::True(()) => panic_with_felt252(Errors::INVALID_TOKEN_ID)
            }
        }

        /// Returns whether `token_id` exists.
        fn _exists(self: @ComponentState<TContractState>, token_id: u256) -> bool {
            !self.ERC721_owners.read(token_id).is_zero()
        }

        /// Returns whether `spender` is allowed to manage `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn _is_approved_or_owner(
            self: @ComponentState<TContractState>, spender: ContractAddress, token_id: u256
        ) -> bool {
            let owner = self._owner_of(token_id);
            let is_approved_for_all = ERC721::is_approved_for_all(self, owner, spender);
            owner == spender
                || is_approved_for_all
                || spender == ERC721::get_approved(self, token_id)
        }

        /// Changes or reaffirms the approved address for an NFT.
        ///
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        /// - `to` is not the current token owner.
        ///
        /// Emits an `Approval` event.
        fn _approve(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);
            assert(owner != to, Errors::APPROVAL_TO_OWNER);

            self.ERC721_token_approvals.write(token_id, to);
            self.emit(Approval { owner, approved: to, token_id });
        }

        /// Enables or disables approval for `operator` to manage
        /// all of the `owner` assets.
        ///
        /// Requirements:
        ///
        /// - `operator` cannot be the caller.
        ///
        /// Emits an `Approval` event.
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

        /// Mints `token_id` and transfers it to `to`.
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `to` is not the zero address.
        /// - `token_id` does not exist.
        ///
        /// Emits a `Transfer` event.
        fn _mint(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            assert(!self._exists(token_id), Errors::ALREADY_MINTED);

            self.ERC721_balances.write(to, self.ERC721_balances.read(to) + 1);
            self.ERC721_owners.write(token_id, to);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }

        /// Transfers `token_id` from `from` to `to`.
        ///
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `to` is not the zero address.
        /// - `from` is the token owner.
        /// - `token_id` exists.
        ///
        /// Emits a `Transfer` event.
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

        /// Destroys `token_id`. The approval is cleared when the token is burned.
        ///
        /// This internal function does not check if the caller is authorized
        /// to operate on the token.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        ///
        /// Emits a `Transfer` event.
        fn _burn(ref self: ComponentState<TContractState>, token_id: u256) {
            let owner = self._owner_of(token_id);

            // Implicit clear approvals, no need to emit an event
            self.ERC721_token_approvals.write(token_id, Zeroable::zero());

            self.ERC721_balances.write(owner, self.ERC721_balances.read(owner) - 1);
            self.ERC721_owners.write(token_id, Zeroable::zero());

            self.emit(Transfer { from: owner, to: Zeroable::zero(), token_id });
        }

        /// Mints `token_id` if `to` is either an account or `IERC721Receiver`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - `token_id` does not exist.
        /// - `to` is either an account contract or supports the `IERC721Receiver` interface.
        ///
        /// Emits a `Transfer` event.
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

        /// Transfers ownership of `token_id` from `from` if `to` is either an account or `IERC721Receiver`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - `to` cannot be the zero address.
        /// - `from` must be the token owner.
        /// - `token_id` exists.
        /// - `to` is either an account contract or supports the `IERC721Receiver` interface.
        ///
        /// Emits a `Transfer` event.
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

        /// Sets the base URI.
        fn _set_base_uri(ref self: ComponentState<TContractState>, base_uri: ByteArray) {
            self.ERC721_base_uri.write(base_uri);
        }

        /// Base URI for computing `token_uri`.
        ///
        /// If set, the resulting URI for each token will be the concatenation of the base URI and the token ID.
        /// Returns an empty `ByteArray` if not set.
        fn _base_uri(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC721_base_uri.read()
        }
    }

    /// Checks if `to` either is an account contract or has registered support
    /// for the `IERC721Receiver` interface through SRC5.
    fn _check_on_erc721_received(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> bool {
        let src5_dispatcher = ISRC5Dispatcher { contract_address: to };

        if src5_dispatcher.supports_interface(interface::IERC721_RECEIVER_ID) {
            DualCaseERC721Receiver { contract_address: to }
                .on_erc721_received(
                    get_caller_address(), from, token_id, data
                ) == interface::IERC721_RECEIVER_ID
        } else {
            src5_dispatcher.supports_interface(account::interface::ISRC6_ID)
        }
    }

    #[embeddable_as(ERC721MixinImpl)]
    impl ERC721Mixin<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::ERC721ABI<ComponentState<TContractState>> {
        // IERC721
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            ERC721::balance_of(self, account)
        }

        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            ERC721::owner_of(self, token_id)
        }

        fn safe_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            ERC721::safe_transfer_from(ref self, from, to, token_id, data);
        }


        fn transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            ERC721::transfer_from(ref self, from, to, token_id);
        }

        fn approve(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            ERC721::approve(ref self, to, token_id);
        }

        fn set_approval_for_all(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            ERC721::set_approval_for_all(ref self, operator, approved);
        }

        fn get_approved(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            ERC721::get_approved(self, token_id)
        }

        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            ERC721::is_approved_for_all(self, owner, operator)
        }

        // IERC721Metadata
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            ERC721Metadata::name(self)
        }

        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            ERC721Metadata::symbol(self)
        }

        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> ByteArray {
            ERC721Metadata::token_uri(self, token_id)
        }

        // IERC721CamelOnly
        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            ERC721CamelOnly::balanceOf(self, account)
        }

        fn ownerOf(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            ERC721CamelOnly::ownerOf(self, tokenId)
        }

        fn safeTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            ERC721CamelOnly::safeTransferFrom(ref self, from, to, tokenId, data);
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256
        ) {
            ERC721CamelOnly::transferFrom(ref self, from, to, tokenId);
        }

        fn setApprovalForAll(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            ERC721CamelOnly::setApprovalForAll(ref self, operator, approved);
        }

        fn getApproved(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            ERC721CamelOnly::getApproved(self, tokenId)
        }

        fn isApprovedForAll(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            ERC721CamelOnly::isApprovedForAll(self, owner, operator)
        }

        // IERC721MetadataCamelOnly
        fn tokenURI(self: @ComponentState<TContractState>, tokenId: u256) -> ByteArray {
            ERC721MetadataCamelOnly::tokenURI(self, tokenId)
        }

        // ISRC5
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            let src5 = get_dep_component!(self, SRC5);
            src5.supports_interface(interface_id)
        }
    }
}
