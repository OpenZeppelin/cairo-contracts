//! # License
//!
//! SPDX-License-Identifier: MIT
//! OpenZeppelin Contracts for Cairo v0.7.0 (token/erc721/erc721.cairo)
//!
//! # ERC721 Contract and Implementation
//!
//! # Example
//!
//! How to extend the ERC721 contract:
//! ```
//! #[starknet::contract]
//! mod MyToken {
//!     use starknet::ContractAddress;
//!     use openzeppelin::token::erc721::ERC721;
//!
//!     #[storage]
//!     struct Storage {}
//!
//!     #[constructor]
//!     fn constructor(
//!         ref self: ContractState,
//!         recipient: ContractAddress,
//!         token_id: u256
//!     ) {
//!         let name = 'MyNFT';
//!         let symbol = 'NFT';
//!
//!         let mut unsafe_state = ERC721::unsafe_new_contract_state();
//!         ERC721::InternalImpl::initializer(ref unsafe_state, name, symbol);
//!         ERC721::InternalImpl::_mint(ref unsafe_state, recipient, token_id);
//!     }
//!
//!    // Define methods that extend the ERC721 standard contract.
//!    #[external(v0)]
//!    fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
//!        let unsafe_state = ERC721::unsafe_new_contract_state();
//!        ERC721::ERC721Impl::balance_of(@unsafe_state, account)
//!    }
//!
//!    ...
//!
//! }
//! ```
#[starknet::contract]
mod ERC721 {
    use array::SpanTrait;
    use openzeppelin::account;
    use openzeppelin::introspection::dual_src5::DualCaseSRC5;
    use openzeppelin::introspection::dual_src5::DualCaseSRC5Trait;
    use openzeppelin::introspection::interface::ISRC5;
    use openzeppelin::introspection::interface::ISRC5Camel;
    use openzeppelin::introspection::src5;
    use openzeppelin::token::erc721::dual721_receiver::DualCaseERC721Receiver;
    use openzeppelin::token::erc721::dual721_receiver::DualCaseERC721ReceiverTrait;
    use openzeppelin::token::erc721::interface;
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _owners: LegacyMap<u256, ContractAddress>,
        _balances: LegacyMap<ContractAddress, u256>,
        _token_approvals: LegacyMap<u256, ContractAddress>,
        _operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        _token_uri: LegacyMap<u256, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll
    }

    /// Emitted when `token_id` token is transferred from `from` to `to`.
    ///
    /// # Arguments
    /// * `from` - The current owner of the NFT.
    /// * `to` - The new owner of the NFT.
    /// * `token_id` - The NFT to transfer.
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256
    }

    /// Emitted when `owner` enables `approved` to manage the `token_id` token.
    ///
    /// # Arguments
    /// * `owner` - The owner of the NFT.
    /// * `approved` - The new approved NFT controller.
    /// * `token_id` - The NFT to approve.
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        approved: ContractAddress,
        token_id: u256
    }

    /// Emitted when `owner` enables or disables (approved) `operator` to manage
    /// all of its assets.
    ///
    /// # Arguments
    /// * `owner` - The owner of the NFT.
    /// * `operator` - Address to add to the set of authorized operators.
    /// * `approved` - `true` if the operator is approved, `false` to revoke approval.
    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        owner: ContractAddress,
        operator: ContractAddress,
        approved: bool
    }

    /// Initializes the state of the ERC721 contract. This includes setting the
    /// NFT name and symbol.
    ///
    /// # Arguments
    /// * `name` - The NFT name.
    /// * `symbol` - The NFT symbol.
    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, symbol: felt252) {
        self.initializer(name, symbol);
    }

    //
    // External
    //

    #[external(v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        /// Checks if the contract supports a specific interface as defined by
        /// `interface_id`.
        /// See: https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-5.md
        ///
        /// # Arguments
        /// * `interface_id` - The calculated interface ID to query.
        /// # Returns
        /// `true` if the interface is supported.
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            let unsafe_state = src5::SRC5::unsafe_new_contract_state();
            src5::SRC5::SRC5Impl::supports_interface(@unsafe_state, interface_id)
        }
    }

    #[external(v0)]
    impl SRC5CamelImpl of ISRC5Camel<ContractState> {
        /// Camel case support.
        /// See [supports_interface](supports_interface).
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            let unsafe_state = src5::SRC5::unsafe_new_contract_state();
            src5::SRC5::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
        }
    }

    #[external(v0)]
    impl ERC721MetadataImpl of interface::IERC721Metadata<ContractState> {
        /// Returns the NFT name.
        ///
        /// # Returns
        /// NFT name.
        fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }

        /// Returns the NFT symbol.
        ///
        /// # Returns
        /// NFT symbol.
        fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }

        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        /// If the URI is not set for the `token_id`, the return value will be `0`.
        ///
        /// # Arguments
        /// `token_id` - The token to query.
        /// # Returns
        /// URI of `token_id`.
        fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
            assert(self._exists(token_id), 'ERC721: invalid token ID');
            self._token_uri.read(token_id)
        }
    }

    #[external(v0)]
    impl ERC721MetadataCamelOnlyImpl of interface::IERC721MetadataCamelOnly<ContractState> {
        /// Camel case support.
        /// See [token_uri](token_uri).
        fn tokenUri(self: @ContractState, tokenId: u256) -> felt252 {
            assert(self._exists(tokenId), 'ERC721: invalid token ID');
            self._token_uri.read(tokenId)
        }
    }

    #[external(v0)]
    impl ERC721Impl of interface::IERC721<ContractState> {
        /// Returns the number of NFTs owned by `account`.
        ///
        /// # Arguments
        /// `account` - The address to query.
        /// # Returns
        /// Number of NFTs owned by `account`.
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            assert(!account.is_zero(), 'ERC721: invalid account');
            self._balances.read(account)
        }

        /// Returns the owner address of `token_id`.
        ///
        /// # Arguments
        /// `token_id` - The token to query.
        /// # Returns
        /// Owner address of `token_id`.
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self._owner_of(token_id)
        }

        /// Returns the address approved for `token_id`.
        ///
        /// # Arguments
        /// `token_id` - The token ID to query.
        /// # Returns
        /// Approved address for the `token_id` NFT, or `0` if there is none.
        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), 'ERC721: invalid token ID');
            self._token_approvals.read(token_id)
        }

        /// Query if `operator` is an authorized operator for `owner`.
        ///
        /// # Arguments
        /// `owner` - The address that owns the NFT.
        /// `operator` - The address that acts on behalf of the `owner`.
        /// # Returns
        /// `true` if `operator` is an authorized operator for `owner`.
        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self._operator_approvals.read((owner, operator))
        }

        /// Change or reaffirm the approved address for an NFT.
        ///
        /// # Arguments
        /// `to` - The new approved NFT controller.
        /// `token_id` - The NFT to approve.
        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || ERC721Impl::is_approved_for_all(@self, owner, caller),
                'ERC721: unauthorized caller'
            );
            self._approve(to, token_id);
        }

        /// Enable or disable approval for `operator` to manage all of the
        /// caller's assets.
        ///
        /// Emits an [Approval](Approval) event.
        ///
        /// # Arguments
        /// `operator` - Address to add to the set of authorized operators.
        /// `approved` - `true` if operator is approved, `false` to revoke approval.
        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            self._set_approval_for_all(get_caller_address(), operator, approved)
        }

        /// Transfer ownership of `token_id` from `from` to `to`.
        ///
        /// Note that the caller is responsible to confirm that the recipient is
        /// capable of receiving ERC721 transfers or else they may be permanently lost.
        /// Usage of [safe_transfer_from](safe_transfer_from) prevents loss, though
        /// the caller must understand this adds an external call which potentially
        /// creates a reentrancy vulnerability.
        ///
        /// Emits a [Transfer](Transfer) event.
        ///
        /// # Arguments
        /// `from` - The current owner of the NFT.
        /// `to` - The new owner.
        /// `token_id` - The NFT to transfer.
        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id),
                'ERC721: unauthorized caller'
            );
            self._transfer(from, to, token_id);
        }

        /// Safely transfer ownership of `token_id` from `from` to `to`, checking first
        /// that `to` is aware of the ERC721 protocol to prevent tokens being locked
        /// forever. For information regarding how contracts communicate their
        /// awareness of the ERC721 protocol, see [ERC721Received](TODO!).
        ///
        /// Emits a [Transfer](Transfer) event.
        ///
        /// # Arguments
        /// `from` - The current owner of the NFT.
        /// `to` - The new owner.
        /// `token_id` - The NFT to transfer.
        /// `data` - Additional data with no specified format, sent in call to `to`.
        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id),
                'ERC721: unauthorized caller'
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
        fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252) {
            self._name.write(name_);
            self._symbol.write(symbol_);

            let mut unsafe_state = src5::SRC5::unsafe_new_contract_state();
            src5::SRC5::InternalImpl::register_interface(ref unsafe_state, interface::IERC721_ID);
            src5::SRC5::InternalImpl::register_interface(
                ref unsafe_state, interface::IERC721_METADATA_ID
            );
        }

        fn _owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self._owners.read(token_id);
            match owner.is_zero() {
                bool::False(()) => owner,
                bool::True(()) => panic_with_felt252('ERC721: invalid token ID')
            }
        }

        fn _exists(self: @ContractState, token_id: u256) -> bool {
            !self._owners.read(token_id).is_zero()
        }

        fn _is_approved_or_owner(
            self: @ContractState, spender: ContractAddress, token_id: u256
        ) -> bool {
            let owner = self._owner_of(token_id);
            let is_approved_for_all = ERC721Impl::is_approved_for_all(self, owner, spender);
            owner == spender
                || is_approved_for_all
                || spender == ERC721Impl::get_approved(self, token_id)
        }

        fn _approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);
            assert(owner != to, 'ERC721: approval to owner');

            self._token_approvals.write(token_id, to);
            self.emit(Approval { owner, approved: to, token_id });
        }

        fn _set_approval_for_all(
            ref self: ContractState,
            owner: ContractAddress,
            operator: ContractAddress,
            approved: bool
        ) {
            assert(owner != operator, 'ERC721: self approval');
            self._operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        fn _mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            assert(!to.is_zero(), 'ERC721: invalid receiver');
            assert(!self._exists(token_id), 'ERC721: token already minted');

            self._balances.write(to, self._balances.read(to) + 1);
            self._owners.write(token_id, to);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }

        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            assert(!to.is_zero(), 'ERC721: invalid receiver');
            let owner = self._owner_of(token_id);
            assert(from == owner, 'ERC721: wrong sender');

            // Implicit clear approvals, no need to emit an event
            self._token_approvals.write(token_id, Zeroable::zero());

            self._balances.write(from, self._balances.read(from) - 1);
            self._balances.write(to, self._balances.read(to) + 1);
            self._owners.write(token_id, to);

            self.emit(Transfer { from, to, token_id });
        }

        fn _burn(ref self: ContractState, token_id: u256) {
            let owner = self._owner_of(token_id);

            // Implicit clear approvals, no need to emit an event
            self._token_approvals.write(token_id, Zeroable::zero());

            self._balances.write(owner, self._balances.read(owner) - 1);
            self._owners.write(token_id, Zeroable::zero());

            self.emit(Transfer { from: owner, to: Zeroable::zero(), token_id });
        }

        fn _safe_mint(
            ref self: ContractState, to: ContractAddress, token_id: u256, data: Span<felt252>
        ) {
            self._mint(to, token_id);
            assert(
                _check_on_erc721_received(Zeroable::zero(), to, token_id, data),
                'ERC721: safe mint failed'
            );
        }

        fn _safe_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            self._transfer(from, to, token_id);
            assert(
                _check_on_erc721_received(from, to, token_id, data), 'ERC721: safe transfer failed'
            );
        }

        fn _set_token_uri(ref self: ContractState, token_id: u256, token_uri: felt252) {
            assert(self._exists(token_id), 'ERC721: invalid token ID');
            self._token_uri.write(token_id, token_uri)
        }
    }

    #[internal]
    fn _check_on_erc721_received(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5 {
            contract_address: to
        }.supports_interface(interface::IERC721_RECEIVER_ID)) {
            DualCaseERC721Receiver {
                contract_address: to
            }
                .on_erc721_received(
                    get_caller_address(), from, token_id, data
                ) == interface::IERC721_RECEIVER_ID
        } else {
            DualCaseSRC5 { contract_address: to }.supports_interface(account::interface::ISRC6_ID)
        }
    }
}
