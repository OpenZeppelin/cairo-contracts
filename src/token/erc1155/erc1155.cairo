// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (token/erc1155/erc1155.cairo)

/// # ERC1155 Component
///
/// The ERC1155 component provides an implementation of the basic standard multi-token.
/// See https://eips.ethereum.org/EIPS/eip-1155.
#[starknet::component]
mod ERC1155Component {
    use openzeppelin::account;
    use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::dual1155_receiver::{
        DualCaseERC1155Receiver, DualCaseERC1155ReceiverTrait
    };
    use openzeppelin::token::erc1155::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC1155_balances: LegacyMap<(u256, ContractAddress), u256>,
        ERC1155_operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        ERC1155_uri: ByteArray,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        TransferSingle: TransferSingle,
        TransferBatch: TransferBatch,
        ApprovalForAll: ApprovalForAll,
        URI: URI
    }

    /// Emitted when `value` token is transferred from `from` to `to` for `id`.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct TransferSingle {
        #[key]
        operator: ContractAddress,
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        id: u256,
        value: u256
    }

    /// Emitted when `values` are transferred from `from` to `to` for `ids`.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct TransferBatch {
        #[key]
        operator: ContractAddress,
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        ids: Span<u256>,
        values: Span<u256>,
    }

    /// Emitted when `account` enables or disables (`approved`) `operator` to manage
    /// all of its assets.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct ApprovalForAll {
        #[key]
        owner: ContractAddress,
        #[key]
        operator: ContractAddress,
        approved: bool
    }

    /// Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
    ///
    /// If an `URI` event was emitted for `id`, the standard guarantees that `value` will equal the value
    /// returned by `IERC1155MetadataURI::uri`.
    /// https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions
    #[derive(Drop, PartialEq, starknet::Event)]
    struct URI {
        value: ByteArray,
        #[key]
        id: u256
    }

    mod Errors {
        const UNAUTHORIZED: felt252 = 'ERC1155: unauthorized operator';
        const SELF_APPROVAL: felt252 = 'ERC1155: self approval';
        const INVALID_RECEIVER: felt252 = 'ERC1155: invalid receiver';
        const INVALID_SENDER: felt252 = 'ERC1155: invalid sender';
        const INVALID_ARRAY_LENGTH: felt252 = 'ERC1155: no equal array length';
        const INSUFFICIENT_BALANCE: felt252 = 'ERC1155: insufficient balance';
        const SAFE_TRANSFER_FAILED: felt252 = 'ERC1155: safe transfer failed';
    }

    //
    // External
    //

    #[embeddable_as(ERC1155Impl)]
    impl ERC1155<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC1155<ComponentState<TContractState>> {
        /// Returns the amount of `token_id` tokens owned by `account`.
        fn balance_of(
            self: @ComponentState<TContractState>, account: ContractAddress, token_id: u256
        ) -> u256 {
            self.ERC1155_balances.read((token_id, account))
        }


        /// Returns a list of balances derived from the `accounts` and `token_ids` pairs.
        ///
        /// Requirements:
        ///
        /// - `token_ids` and `accounts` must have the same length.
        fn balance_of_batch(
            self: @ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            token_ids: Span<u256>
        ) -> Span<u256> {
            assert(accounts.len() == token_ids.len(), Errors::INVALID_ARRAY_LENGTH);

            let mut batch_balances = array![];
            let mut index = 0;
            loop {
                if index == token_ids.len() {
                    break;
                }
                batch_balances
                    .append(ERC1155::balance_of(self, *accounts.at(index), *token_ids.at(index)));
                index += 1;
            };

            batch_balances.span()
        }

        /// Transfers ownership of `value` amount of `token_id` from `from` if `to` is either an account or `IERC1155Receiver`.
        ///
        /// `data` is additional data, it has no specified format and it is passed to `to`.
        ///
        /// WARNING: This function can potentially allow a reentrancy attack when transferring tokens
        /// to an untrusted contract, when invoking `on_ERC1155_received` on the receiver.
        /// Ensure to follow the checks-effects-interactions pattern and consider employing
        /// reentrancy guards when interacting with untrusted contracts.
        ///
        /// Requirements:
        ///
        /// - Caller is either approved or the `token_id` owner.
        /// - `from` is not the zero address.
        /// - `to` is not the zero address.
        /// - If `to` refers to a non-account contract, it must implement `IERC1155Receiver::on_ERC1155_received`
        ///   and return the required magic value.
        ///
        /// Emits a `TransferSingle` event.
        fn safe_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) {
            let token_ids = array![token_id].span();
            let values = array![value].span();
            ERC1155::safe_batch_transfer_from(ref self, from, to, token_ids, values, data)
        }

        /// Batched version of `safe_transfer_from`.
        ///
        /// WARNING: This function can potentially allow a reentrancy attack when transferring tokens
        /// to an untrusted contract, when invoking `on_ERC1155_batch_received` on the receiver.
        /// Ensure to follow the checks-effects-interactions pattern and consider employing
        /// reentrancy guards when interacting with untrusted contracts.
        ///
        /// Requirements:
        ///
        /// - Caller is either approved or the `token_id` owner.
        /// - `from` is not the zero address.
        /// - `to` is not the zero address.
        /// - `token_ids` and `values` must have the same length.
        /// - If `to` refers to a non-account contract, it must implement `IERC1155Receiver::on_ERC1155_batch_received`
        ///   and return the acceptance magic value.
        ///
        /// Emits either a `TransferSingle` or a `TransferBatch` event, depending on the length of the array arguments.
        fn safe_batch_transfer_from(
            ref self: ComponentState<TContractState>,
            from: starknet::ContractAddress,
            to: starknet::ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            assert(from.is_non_zero(), Errors::INVALID_SENDER);
            assert(to.is_non_zero(), Errors::INVALID_RECEIVER);

            let operator = get_caller_address();
            if from != operator {
                assert(ERC1155::is_approved_for_all(@self, from, operator), Errors::UNAUTHORIZED);
            }

            self.update_with_acceptance_check(from, to, token_ids, values, data);
        }

        /// Enables or disables approval for `operator` to manage all of the
        /// callers assets.
        ///
        /// Requirements:
        ///
        /// - `operator` cannot be the caller.
        ///
        /// Emits an `ApprovalForAll` event.
        fn set_approval_for_all(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            let owner = get_caller_address();
            assert(owner != operator, Errors::SELF_APPROVAL);

            self.ERC1155_operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        /// Queries if `operator` is an authorized operator for `owner`.
        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC1155_operator_approvals.read((owner, operator))
        }
    }

    #[embeddable_as(ERC1155MetadataURIImpl)]
    impl ERC1155MetadataURI<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC1155MetadataURI<ComponentState<TContractState>> {
        /// This implementation returns the same URI for *all* token types. It relies
        /// on the token type ID substitution mechanism defined in the EIP:
        /// https://eips.ethereum.org/EIPS/eip-1155#metadata.
        ///
        /// Clients calling this function must replace the `\{id\}` substring with the
        /// actual token type ID.
        fn uri(self: @ComponentState<TContractState>, token_id: u256) -> ByteArray {
            self.ERC1155_uri.read()
        }
    }

    /// Adds camelCase support for `IERC1155`.
    #[embeddable_as(ERC1155CamelImpl)]
    impl ERC1155Camel<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC1155Camel<ComponentState<TContractState>> {
        fn balanceOf(
            self: @ComponentState<TContractState>, account: ContractAddress, tokenId: u256
        ) -> u256 {
            ERC1155::balance_of(self, account, tokenId)
        }

        fn balanceOfBatch(
            self: @ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            tokenIds: Span<u256>
        ) -> Span<u256> {
            ERC1155::balance_of_batch(self, accounts, tokenIds)
        }

        fn safeTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            value: u256,
            data: Span<felt252>
        ) {
            ERC1155::safe_transfer_from(ref self, from, to, tokenId, value, data)
        }

        fn safeBatchTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            ERC1155::safe_batch_transfer_from(ref self, from, to, tokenIds, values, data)
        }

        fn setApprovalForAll(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            ERC1155::set_approval_for_all(ref self, operator, approved)
        }

        fn isApprovedForAll(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            ERC1155::is_approved_for_all(self, owner, operator)
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
        /// Initializes the contract by setting the `base_uri` for all tokens,
        /// and registering the supported interfaces.
        /// This should only be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>, base_uri: ByteArray) {
            self.set_base_uri(base_uri);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC1155_ID);
            src5_component.register_interface(interface::IERC1155_METADATA_URI_ID);
        }

        /// Transfers a `value` amount of tokens of type `id` from `from` to `to`.
        /// Will mint (or burn) if `from` (or `to`) is the zero address.
        ///
        /// Requirements:
        ///
        /// - `token_ids` and `values` must have the same length.
        ///
        /// Emits a `TransferSingle` event if the arrays contain one element, and `TransferBatch` otherwise.
        ///
        /// NOTE: The ERC1155 acceptance check is not performed in this function.
        /// See `update_with_acceptance_check` instead.
        fn update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>
        ) {
            assert(token_ids.len() == values.len(), Errors::INVALID_ARRAY_LENGTH);

            let mut index = 0;
            loop {
                if index == token_ids.len() {
                    break;
                }
                let token_id = *token_ids.at(index);
                let value = *values.at(index);
                if from.is_non_zero() {
                    let from_balance = self.ERC1155_balances.read((token_id, from));
                    assert(from_balance >= value, Errors::INSUFFICIENT_BALANCE);
                    self.ERC1155_balances.write((token_id, from), from_balance - value);
                }
                if to.is_non_zero() {
                    let to_balance = self.ERC1155_balances.read((token_id, to));
                    self.ERC1155_balances.write((token_id, to), to_balance + value);
                }
                index += 1;
            };
            let operator = get_caller_address();
            if token_ids.len() == 1 {
                self
                    .emit(
                        TransferSingle {
                            operator, from, to, id: *token_ids.at(0), value: *values.at(0)
                        }
                    );
            } else {
                self.emit(TransferBatch { operator, from, to, ids: token_ids, values });
            }
        }

        /// Version of `update` that performs the token acceptance check by calling
        /// `IERC1155Receiver::onERC1155Received` or `IERC1155Receiver::onERC1155BatchReceived` if
        /// the receiver is not recognized as an account.
        ///
        /// Requirements:
        ///
        /// - `to` is either an account contract or supports the `IERC1155Receiver` interface.
        /// - `token_ids` and `values` must have the same length.
        ///
        /// Emits a `TransferSingle` event if the arrays contain one element, and `TransferBatch` otherwise.
        fn update_with_acceptance_check(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            self.update(from, to, token_ids, values);
            let accepted = if token_ids.len() == 1 {
                _check_on_ERC1155_received(from, to, *token_ids.at(0), *values.at(0), data)
            } else {
                _check_on_ERC1155_batch_received(from, to, token_ids, values, data)
            };
            assert(accepted, Errors::SAFE_TRANSFER_FAILED);
        }

        /// Creates a `value` amount of tokens of type `token_id`, and assigns them to `to`.
        ///
        /// Requirements:
        ///
        /// - `to` cannot be the zero address.
        /// - If `to` refers to a smart contract, it must implement `IERC1155Receiver::on_ERC1155_received`
        /// and return the acceptance magic value.
        ///
        /// Emits a `TransferSingle` event.
        fn mint_with_acceptance_check(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) {
            assert(to.is_non_zero(), Errors::INVALID_RECEIVER);

            let token_ids = array![token_id].span();
            let values = array![value].span();
            self.update_with_acceptance_check(Zeroable::zero(), to, token_ids, values, data);
        }

        /// Batched version of `mint_with_acceptance_check`.
        ///
        /// Requirements:
        ///
        /// - `to` cannot be the zero address.
        /// - `token_ids` and `values` must have the same length.
        /// - If `to` refers to a smart contract, it must implement `IERC1155Receiver::on_ERC1155_batch_received`
        /// and return the acceptance magic value.
        ///
        /// Emits a `TransferBatch` event.
        fn batch_mint_with_acceptance_check(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            assert(to.is_non_zero(), Errors::INVALID_RECEIVER);
            self.update_with_acceptance_check(Zeroable::zero(), to, token_ids, values, data);
        }

        /// Destroys a `value` amount of tokens of type `token_id` from `from`.
        ///
        /// Requirements:
        ///
        /// - `from` cannot be the zero address.
        /// - `from` must have at least `value` amount of tokens of type `token_id`.
        ///
        /// Emits a `TransferSingle` event.
        fn burn(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            token_id: u256,
            value: u256
        ) {
            assert(from.is_non_zero(), Errors::INVALID_SENDER);

            let token_ids = array![token_id].span();
            let values = array![value].span();
            self.update(from, Zeroable::zero(), token_ids, values);
        }

        /// Batched version of `burn`.
        ///
        /// Requirements:
        ///
        /// - `from` cannot be the zero address.
        /// - `from` must have at least `value` amount of tokens of type `token_id`.
        /// - `token_ids` and `values` must have the same length.
        ///
        /// Emits a `TransferBatch` event.
        fn batch_burn(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>
        ) {
            assert(from.is_non_zero(), Errors::INVALID_SENDER);
            self.update(from, Zeroable::zero(), token_ids, values);
        }

        /// Sets a new URI for all token types, by relying on the token type ID
        /// substitution mechanism defined in the ERC1155 standard.
        /// See https://eips.ethereum.org/EIPS/eip-1155#metadata.
        ///
        /// By this mechanism, any occurrence of the `\{id\}` substring in either the
        /// URI or any of the values in the JSON file at said URI will be replaced by
        /// clients with the token type ID.
        ///
        /// For example, the `https://token-cdn-domain/\{id\}.json` URI would be
        /// interpreted by clients as
        /// `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
        /// for token type ID 0x4cce0.
        ///
        /// Because these URIs cannot be meaningfully represented by the `URI` event,
        /// this function emits no events.
        fn set_base_uri(ref self: ComponentState<TContractState>, base_uri: ByteArray) {
            self.ERC1155_uri.write(base_uri);
        }
    }

    /// Checks if `to` accepts the token by implementing `IERC1155Receiver`
    /// or if it's an account contract (supporting ISRC6).
    fn _check_on_ERC1155_received(
        from: ContractAddress, to: ContractAddress, token_id: u256, value: u256, data: Span<felt252>
    ) -> bool {
        let src5_dispatcher = ISRC5Dispatcher { contract_address: to };

        if src5_dispatcher.supports_interface(interface::IERC1155_RECEIVER_ID) {
            DualCaseERC1155Receiver { contract_address: to }
                .on_erc1155_received(
                    get_caller_address(), from, token_id, value, data
                ) == interface::IERC1155_RECEIVER_ID
        } else {
            src5_dispatcher.supports_interface(account::interface::ISRC6_ID)
        }
    }

    /// Checks if `to` accepts the token by implementing `IERC1155Receiver`
    /// or if it's an account contract (supporting ISRC6).
    fn _check_on_ERC1155_batch_received(
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> bool {
        let src5_dispatcher = ISRC5Dispatcher { contract_address: to };

        if src5_dispatcher.supports_interface(interface::IERC1155_RECEIVER_ID) {
            DualCaseERC1155Receiver { contract_address: to }
                .on_erc1155_batch_received(
                    get_caller_address(), from, token_ids, values, data
                ) == interface::IERC1155_RECEIVER_ID
        } else {
            src5_dispatcher.supports_interface(account::interface::ISRC6_ID)
        }
    }

    #[embeddable_as(ERC1155MixinImpl)]
    impl ERC1155Mixin<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::ERC1155ABI<ComponentState<TContractState>> {
        // IERC1155
        fn balance_of(
            self: @ComponentState<TContractState>, account: ContractAddress, token_id: u256
        ) -> u256 {
            ERC1155::balance_of(self, account, token_id)
        }

        fn balance_of_batch(
            self: @ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            token_ids: Span<u256>
        ) -> Span<u256> {
            ERC1155::balance_of_batch(self, accounts, token_ids)
        }

        fn safe_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) {
            ERC1155::safe_transfer_from(ref self, from, to, token_id, value, data);
        }

        fn safe_batch_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            ERC1155::safe_batch_transfer_from(ref self, from, to, token_ids, values, data);
        }

        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            ERC1155::is_approved_for_all(self, owner, operator)
        }

        fn set_approval_for_all(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            ERC1155::set_approval_for_all(ref self, operator, approved);
        }

        // ISRC5
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            let src5 = get_dep_component!(self, SRC5);
            src5.supports_interface(interface_id)
        }

        // IERC1155MetadataURI
        fn uri(self: @ComponentState<TContractState>, token_id: u256) -> ByteArray {
            ERC1155MetadataURI::uri(self, token_id)
        }

        // IERC1155Camel
        fn balanceOf(
            self: @ComponentState<TContractState>, account: ContractAddress, tokenId: u256
        ) -> u256 {
            ERC1155Camel::balanceOf(self, account, tokenId)
        }

        fn balanceOfBatch(
            self: @ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            tokenIds: Span<u256>
        ) -> Span<u256> {
            ERC1155Camel::balanceOfBatch(self, accounts, tokenIds)
        }

        fn safeTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            value: u256,
            data: Span<felt252>
        ) {
            ERC1155Camel::safeTransferFrom(ref self, from, to, tokenId, value, data);
        }

        fn safeBatchTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            ERC1155Camel::safeBatchTransferFrom(ref self, from, to, tokenIds, values, data);
        }

        fn isApprovedForAll(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            ERC1155Camel::isApprovedForAll(self, owner, operator)
        }

        fn setApprovalForAll(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            ERC1155Camel::setApprovalForAll(ref self, operator, approved);
        }
    }
}
