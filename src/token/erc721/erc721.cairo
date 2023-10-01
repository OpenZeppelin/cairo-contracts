//! SPDX-License-Identifier: MIT
//! OpenZeppelin Contracts for Cairo v0.7.0 (token/erc721/erc721.cairo)
//!
//! # ERC721 Contract and Implementation
//!
//! This ERC721 contract includes both a library and a basic preset implementation
//! which includes the IERC721Metadata implementation.
#[starknet::contract]
mod ERC721 {
    use openzeppelin::account;
    use openzeppelin::introspection::dual_src5::DualCaseSRC5;
    use openzeppelin::introspection::dual_src5::DualCaseSRC5Trait;
    use openzeppelin::introspection::interface::ISRC5;
    use openzeppelin::introspection::interface::ISRC5Camel;
    use openzeppelin::introspection::src5::unsafe_state as src5_state;
    use openzeppelin::introspection::src5;
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
        ApprovalForAll: ApprovalForAll
    }

    /// Emitted when `token_id` token is transferred from `from` to `to`.
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables `approved` to manage the `token_id` token.
    #[derive(Drop, starknet::Event)]
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

    /// Initializes the state of the ERC721 contract. This includes setting both the
    /// NFT name and symbol as well as minting `token_id` to `recipient`.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        recipient: ContractAddress,
        token_id: u256
    ) {
        self.initializer(name, symbol);
        self._mint(recipient, token_id);
    }

    //
    // External
    //

    #[external(v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        /// Checks if the contract supports a specific interface as defined by
        /// `interface_id`.
        /// See: https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-5.md
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            src5::SRC5::SRC5Impl::supports_interface(@src5_state(), interface_id)
        }
    }

    #[external(v0)]
    impl SRC5CamelImpl of ISRC5Camel<ContractState> {
        /// Camel case support.
        /// See [supports_interface](supports_interface).
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            src5::SRC5::SRC5CamelImpl::supportsInterface(@src5_state(), interfaceId)
        }
    }

    #[external(v0)]
    impl ERC721MetadataImpl of interface::IERC721Metadata<ContractState> {
        /// Returns the NFT name.
        fn name(self: @ContractState) -> felt252 {
            self.ERC721_name.read()
        }

        /// Returns the NFT symbol.
        fn symbol(self: @ContractState) -> felt252 {
            self.ERC721_symbol.read()
        }

        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        /// If the URI is not set for the `token_id`, the return value will be `0`.
        fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_uri.read(token_id)
        }
    }

    #[external(v0)]
    impl ERC721MetadataCamelOnlyImpl of interface::IERC721MetadataCamelOnly<ContractState> {
        /// Camel case support.
        /// See [token_uri](token_uri).
        fn tokenURI(self: @ContractState, tokenId: u256) -> felt252 {
            assert(self._exists(tokenId), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_uri.read(tokenId)
        }
    }

    #[external(v0)]
    impl ERC721Impl of interface::IERC721<ContractState> {
        /// Returns the number of NFTs owned by `account`.
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            assert(!account.is_zero(), Errors::INVALID_ACCOUNT);
            self.ERC721_balances.read(account)
        }

        /// Returns the owner address of `token_id`.
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self._owner_of(token_id)
        }

        /// Returns the address approved for `token_id`.
        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_approvals.read(token_id)
        }

        /// Query if `operator` is an authorized operator for `owner`.
        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC721_operator_approvals.read((owner, operator))
        }

        /// Change or reaffirm the approved address for an NFT.
        /// Emits an [Approval](Approval) event.
        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || ERC721Impl::is_approved_for_all(@self, owner, caller),
                Errors::UNAUTHORIZED
            );
            self._approve(to, token_id);
        }

        /// Enable or disable approval for `operator` to manage all of the
        /// caller's assets.
        /// Emits an [Approval](Approval) event.
        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            self._set_approval_for_all(get_caller_address(), operator, approved)
        }

        /// Transfer ownership of `token_id` from `from` to `to`.
        /// Emits a [Transfer](Transfer) event.
        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id), Errors::UNAUTHORIZED
            );
            self._transfer(from, to, token_id);
        }

        /// Safely transfer ownership of `token_id` from `from` to `to`.
        /// If `to` is not an account contract, `to` must support IERC721Receiver;
        /// otherwise, the transaction will fail.
        /// Emits a [Transfer](Transfer) event.
        fn safe_transfer_from(
            ref self: ContractState,
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

    #[external(v0)]
    impl ERC721CamelOnlyImpl of interface::IERC721CamelOnly<ContractState> {
        /// Camel case support.
        /// See [balance_of](balance_of).
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            ERC721Impl::balance_of(self, account)
        }

        /// Camel case support.
        /// See [owner_of](owner_of).
        fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress {
            ERC721Impl::owner_of(self, tokenId)
        }

        /// Camel case support.
        /// See [get_approved](get_approved).
        fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress {
            ERC721Impl::get_approved(self, tokenId)
        }

        /// Camel case support.
        /// See [is_approved_for_all](is_approved_for_all).
        fn isApprovedForAll(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            ERC721Impl::is_approved_for_all(self, owner, operator)
        }

        /// Camel case support.
        /// See [set_approval_for_all](set_approval_for_all).
        fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
            ERC721Impl::set_approval_for_all(ref self, operator, approved)
        }

        /// Camel case support.
        /// See [transfer_from](transfer_from).
        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        ) {
            ERC721Impl::transfer_from(ref self, from, to, tokenId)
        }

        /// Camel case support.
        /// See [safe_transfer_from](safe_transfer_from).
        fn safeTransferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            ERC721Impl::safe_transfer_from(ref self, from, to, tokenId, data)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Initializes the contract by setting the token name and symbol.
        /// This should be used inside the contract's constructor.
        fn initializer(ref self: ContractState, name: felt252, symbol: felt252) {
            self.ERC721_name.write(name);
            self.ERC721_symbol.write(symbol);

            let mut unsafe_state = src5_state();
            src5::SRC5::InternalImpl::register_interface(ref unsafe_state, interface::IERC721_ID);
            src5::SRC5::InternalImpl::register_interface(
                ref unsafe_state, interface::IERC721_METADATA_ID
            );
        }

        /// Returns the owner address of `token_id`.
        fn _owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.ERC721_owners.read(token_id);
            match owner.is_zero() {
                bool::False(()) => owner,
                bool::True(()) => panic_with_felt252(Errors::INVALID_TOKEN_ID)
            }
        }

        /// Returns whether `token_id` exists.
        fn _exists(self: @ContractState, token_id: u256) -> bool {
            !self.ERC721_owners.read(token_id).is_zero()
        }

        /// Returns whether `spender` is allowed to manage `token_id`.
        fn _is_approved_or_owner(
            self: @ContractState, spender: ContractAddress, token_id: u256
        ) -> bool {
            let owner = self._owner_of(token_id);
            let is_approved_for_all = ERC721Impl::is_approved_for_all(self, owner, spender);
            owner == spender
                || is_approved_for_all
                || spender == ERC721Impl::get_approved(self, token_id)
        }

        /// Internal function that changes or reaffirms the approved address for an NFT.
        /// Emits an [Approval[(Approval) event.
        fn _approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);
            assert(owner != to, Errors::APPROVAL_TO_OWNER);

            self.ERC721_token_approvals.write(token_id, to);
            self.emit(Approval { owner, approved: to, token_id });
        }

        /// Internal function that enables or disables approval for `operator`
        /// to manage all of the `owner` assets.
        /// Emits an [Approval[(Approval) event.
        fn _set_approval_for_all(
            ref self: ContractState,
            owner: ContractAddress,
            operator: ContractAddress,
            approved: bool
        ) {
            assert(owner != operator, Errors::SELF_APPROVAL);
            self.ERC721_operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        /// Internal function that mints `token_id` and transfers it to `to`.
        /// Emits a [Transfer](Transfer) event.
        fn _mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            assert(!self._exists(token_id), Errors::ALREADY_MINTED);

            self.ERC721_balances.write(to, self.ERC721_balances.read(to) + 1);
            self.ERC721_owners.write(token_id, to);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }

        /// Internal function that transfers `token_id` from `from` to `to`.
        /// Emits a [Transfer](Transfer) event.
        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
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

        /// Internal function that destroys `token_id`. The approval is cleared when
        /// the token is burned.
        /// This internal function does not check if the sender is authorized
        /// to operate on the token.
        /// Emits a [Transfer](Transfer) event.
        fn _burn(ref self: ContractState, token_id: u256) {
            let owner = self._owner_of(token_id);

            // Implicit clear approvals, no need to emit an event
            self.ERC721_token_approvals.write(token_id, Zeroable::zero());

            self.ERC721_balances.write(owner, self.ERC721_balances.read(owner) - 1);
            self.ERC721_owners.write(token_id, Zeroable::zero());

            self.emit(Transfer { from: owner, to: Zeroable::zero(), token_id });
        }

        /// Internal function that safely mints `token_id` and transfers it to `to`.
        /// If `to` is not an account contract, `to` must support IERC721Receiver;
        /// otherwise, the transaction will fail.
        /// Emits a [Transfer](Transfer) event.
        fn _safe_mint(
            ref self: ContractState, to: ContractAddress, token_id: u256, data: Span<felt252>
        ) {
            self._mint(to, token_id);
            assert(
                _check_on_erc721_received(Zeroable::zero(), to, token_id, data),
                Errors::SAFE_MINT_FAILED
            );
        }

        /// Internal function that safely transfers `token_id` token from `from` to `to`,
        /// If `to` is not an account contract, `to` must support IERC721Receiver;
        /// otherwise, the transaction will fail.
        /// Emits a [Transfer](Transfer) event.
        fn _safe_transfer(
            ref self: ContractState,
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

        /// Sets the `token_uri` of `token_id`.
        fn _set_token_uri(ref self: ContractState, token_id: u256, token_uri: felt252) {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_uri.write(token_id, token_uri)
        }
    }

    #[internal]
    /// Internal function that checks if `to` either is an account contract or
    /// has registered support for the ERC721 interface through SRC-5.
    /// The transaction will fail if both cases are false.
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
