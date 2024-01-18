// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (token/erc1155/erc1155.cairo)

/// # IERC1155 Component
///
/// The IERC1155 component provides implementations for both the IIERC1155 interface
/// and the IIERC1155Metadata interface.
#[starknet::component]
mod ERC1155Component {
    use openzeppelin::account;
    use openzeppelin::introspection::dual_src5::{DualCaseSRC5, DualCaseSRC5Trait};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::dual1155_receiver::{
        DualCaseERC1155Receiver, DualCaseERC1155ReceiverTrait
    };
    use openzeppelin::token::erc1155::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC1155_name: felt252,
        ERC1155_symbol: felt252,
        ERC1155_balances: LegacyMap<(u256, ContractAddress), u256>,
        ERC1155_operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        ERC1155_uri: LegacyMap<u256, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransferSingle: TransferSingle,
        TransferBatch: TransferBatch,
        ApprovalForAll: ApprovalForAll,
        URI: URI,
    }

    /// Emitted when `value` token is transferred from `from` to `to` for `id`.
    #[derive(Drop, starknet::Event)]
    struct TransferSingle {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        id: u256,
        value: u256
    }

    /// Emitted when `values` are transferred from `from` to `to` for `id`.
    #[derive(Drop, starknet::Event)]
    struct TransferBatch {
        #[key]
        operator: starknet::ContractAddress,
        #[key]
        from: starknet::ContractAddress,
        #[key]
        to: starknet::ContractAddress,
        #[key]
        ids: Span<u256>,
        values: Span<u256>,
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

    /// Emitted when the `URI` is updated for a token `id`.
    /// all of its assets.
    #[derive(Drop, starknet::Event)]
    struct URI {
        value: felt252,
        #[key]
        id: u256,
    }

    mod Errors {
        const INVALID_TOKEN_ID: felt252 = 'ERC1155: invalid token ID';
        const INVALID_ACCOUNT: felt252 = 'ERC1155: invalid account';
        const UNAUTHORIZED: felt252 = 'ERC1155: unauthorized caller';
        const APPROVAL_TO_OWNER: felt252 = 'ERC1155: approval to owner';
        const SELF_APPROVAL: felt252 = 'ERC1155: self approval';
        const INVALID_RECEIVER: felt252 = 'ERC1155: invalid receiver';
        const ALREADY_MINTED: felt252 = 'ERC1155: token already minted';
        const WRONG_SENDER: felt252 = 'ERC1155: wrong sender';
        const SAFE_MINT_FAILED: felt252 = 'ERC1155: safe mint failed';
        const SAFE_TRANSFER_FAILED: felt252 = 'ERC1155: safe transfer failed';
        const INVALID_LEN_ACCOUNTS_IDS: felt252 = 'ERC1155: no equal array length';
        const INVALID_ARRAY_LENGTH: felt252 = 'ERC1155: invalid array length';
        const INSUFFICIENT_BALANCE: felt252 = 'ERC1155: insufficient balance';
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
        /// Returns the number of value of NFT owned by `account`.
        /// Retrieves the balance of a specific ERC1155 token for a given account.
        ///
        /// Parameters:
        /// - account: The address of the account to check the balance for.
        /// - token_id: The ID of the ERC1155 token.
        ///
        /// Returns:
        /// - The balance of the specified ERC1155 token for the given account.
        fn balance_of(
            self: @ComponentState<TContractState>, account: ContractAddress, token_id: u256
        ) -> u256 {
            assert(!account.is_zero(), Errors::INVALID_ACCOUNT);
            self.ERC1155_balances.read((token_id, account))
        }


        /// Retrieves the batch balances of multiple accounts for a given set of token IDs.
        ///
        /// # Arguments
        ///
        /// - `accounts`: A span of contract addresses representing the accounts to retrieve balances for.
        /// - `token_ids`: A span of u256 values representing the token IDs to retrieve balances for.
        ///
        /// # Returns
        ///
        /// A span of u256 values representing the batch balances of the accounts for the specified token IDs.
        ///
        /// # Panics
        ///
        /// This function will panic if the length of `accounts` is not equal to the length of `token_ids`.
        fn balance_of_batch(
            self: @ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            token_ids: Span<u256>
        ) -> Span<u256> {
            assert(accounts.len() == token_ids.len(), Errors::INVALID_LEN_ACCOUNTS_IDS);

            let mut batch_balances = array![];
            let mut index = 0;
            loop {
                if index == token_ids.len() {
                    break batch_balances.clone();
                }
                batch_balances.append(self.balance_of(*accounts.at(index), *token_ids.at(index)));
                index += 1;
            };

            batch_balances.span()
        }

        /// Transfers ownership of `token_id` from `from` if `to` is either an account or `IERC1155Receiver`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - Caller is either approved or the `token_id` owner.
        /// - `to` is not the zero address.
        /// - `from` is not the zero address.
        /// - `token_id` exists.
        /// - `to` is either an account contract or supports the `IERC1155Receiver` interface.
        ///
        /// Emits a `Transfer` event.
        fn safe_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) {
            assert(self.is_approved_for_all(get_caller_address(), from), Errors::UNAUTHORIZED);
            self._safe_update_balances(from, to, token_id, value, data);
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
            token_id: u256,
            value: u256
        ) {
            assert(self.is_approved_for_all(get_caller_address(), from), Errors::UNAUTHORIZED);
            self._update_balances(from, to, token_id, value);
        }

        fn safe_batch_transfer_from(
            ref self: ComponentState<TContractState>,
            from: starknet::ContractAddress,
            to: starknet::ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            assert(from.is_non_zero(), Errors::WRONG_SENDER);
            assert(self.is_approved_for_all(get_caller_address(), from), Errors::UNAUTHORIZED);

            self._safe_batch_transfer_from(from, to, token_ids, values, data);
        }

        fn batch_transfer_from(
            ref self: ComponentState<TContractState>,
            from: starknet::ContractAddress,
            to: starknet::ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>
        ) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            assert(from.is_non_zero(), Errors::WRONG_SENDER);
            assert(self.is_approved_for_all(get_caller_address(), from), Errors::UNAUTHORIZED);

            self._batch_transfer_from(from, to, token_ids, values);
        }

        /// Enable or disable approval for `operator` to manage all of the
        /// caller s assets.
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

        /// Query if `operator` is an authorized operator for `owner`.
        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC1155_operator_approvals.read((owner, operator)) || owner == operator
        }
    }

    #[embeddable_as(ERC1155MetadataImpl)]
    impl ERC1155Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC1155Metadata<ComponentState<TContractState>> {
        /// Returns the NFT Collection name.
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            self.ERC1155_name.read()
        }

        /// Returns the NFT Collection symbol.
        fn symbol(self: @ComponentState<TContractState>) -> felt252 {
            self.ERC1155_symbol.read()
        }
        /// Returns the Uniform Resource Identifier (URI) for the `token_id` token.
        /// If the URI is not set for the `token_id`, the return value will be `0`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn uri(self: @ComponentState<TContractState>, token_id: u256) -> felt252 {
            self.ERC1155_uri.read(token_id)
        }
    }

    /// Adds camelCase support for `IERC1155`.
    #[embeddable_as(ERC1155CamelOnlyImpl)]
    impl ERC1155CamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC1155CamelOnly<ComponentState<TContractState>> {
        fn balanceOf(
            self: @ComponentState<TContractState>, account: ContractAddress, tokenId: u256
        ) -> u256 {
            self.balance_of(account, tokenId)
        }

        fn balanceOfBatch(
            self: @ComponentState<TContractState>,
            accounts: Span<ContractAddress>,
            tokenIds: Span<u256>
        ) -> Span<u256> {
            self.balance_of_batch(accounts, tokenIds)
        }

        fn safeTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            value: u256,
            data: Span<felt252>
        ) {
            self.safe_transfer_from(from, to, tokenId, value, data)
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            value: u256
        ) {
            self.transfer_from(from, to, tokenId, value)
        }

        fn safeBatchTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            self.safe_batch_transfer_from(from, to, tokenIds, values, data)
        }

        fn batchTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>
        ) {
            self.batch_transfer_from(from, to, tokenIds, values)
        }

        fn setApprovalForAll(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            self.set_approval_for_all(operator, approved)
        }

        fn isApprovedForAll(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.is_approved_for_all(owner, operator)
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
        /// Initializes the contract by setting the token name and symbol.
        /// This should only be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>, name: felt252, symbol: felt252) {
            self.ERC1155_name.write(name);
            self.ERC1155_symbol.write(symbol);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC1155_ID);
            src5_component.register_interface(interface::IERC1155_METADATA_ID);
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
            self.ERC1155_operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        fn _safe_batch_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            mut token_ids: Span<u256>,
            mut values: Span<u256>,
            data: Span<felt252>
        ) {
            assert(token_ids.len() == values.len(), Errors::INVALID_ARRAY_LENGTH);

            loop {
                if token_ids.len() == 0 {
                    break ();
                }
                let token_id = *token_ids.pop_front().unwrap();
                let value = *values.pop_front().unwrap();

                self._safe_update_balances(from, to, token_id, value, data);
            };

            self
                .emit(
                    TransferBatch { operator: get_caller_address(), from, to, ids: token_ids, values }
                );
        }

        fn _batch_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            mut token_ids: Span<u256>,
            mut values: Span<u256>
        ) {
            assert(token_ids.len() == values.len(), Errors::INVALID_ARRAY_LENGTH);

            loop {
                if token_ids.len() == 0 {
                    break ();
                }
                let token_id = *token_ids.pop_front().unwrap();
                let value = *values.pop_front().unwrap();

                self._update_balances(from, to, token_id, value);
            };

            self
                .emit(
                    TransferBatch { operator: get_caller_address(), from, to, ids: token_ids, values }
                );
        }

        /// Transfers ownership of `token_id` from `from` if `to` is either an account or `IERC1155Receiver`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - `to` cannot be the zero address.
        /// - `from` must be the token owner.
        /// - `token_id` exists.
        /// - `to` is either an account contract or supports the `IERC1155Receiver` interface.
        ///
        /// Emits a `Transfer` event.
        fn _safe_update_balances(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) {
            self._update_balances(from, to, token_id, value);
            assert(
                _check_on_ERC1155_received(from, to, token_id, value, data),
                Errors::SAFE_TRANSFER_FAILED
            );
        }

        /// Transfers `value`  from `from` to `to` of the `token_id`.
        ///
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `to` is not the zero address.
        /// - `from` is the token owner.
        /// - `token_id` exists.
        /// - `value` exists.        
        ///
        /// Emits a `Transfer` event.
        fn _update_balances(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256
        ) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            assert(from.is_non_zero(), Errors::WRONG_SENDER);
            assert(
                self.ERC1155_balances.read((token_id, from)) >= value, Errors::INSUFFICIENT_BALANCE
            );

            self
                .ERC1155_balances
                .write((token_id, from), self.ERC1155_balances.read((token_id, from)) - value);
            self
                .ERC1155_balances
                .write((token_id, to), self.ERC1155_balances.read((token_id, to)) + value);

            self.emit(TransferSingle { from, to, id: token_id, value });
        }

        fn _batch_burn(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            mut token_ids: Span<u256>,
            mut values: Span<u256>
        ) {
            assert(token_ids.len() == values.len(), Errors::INVALID_ARRAY_LENGTH);

            loop {
                if token_ids.len() == 0 {
                    break ();
                }
                let token_id = *token_ids.pop_front().unwrap();
                let value = *values.pop_front().unwrap();

                self._burn(from, token_id, value);
            };

            self
                .emit(
                    TransferBatch { operator: get_caller_address(), from, to: Zeroable::zero(), ids: token_ids, values }
                );
        }

        /// Destroys `value`. The approval is cleared when the token is burned.
        ///
        /// This internal function does not check if the caller is authorized
        /// to operate on the token.
        ///
        /// Requirements:
        ///
        /// - `value` >= balances.
        ///
        /// Emits a `Transfer` event.
        fn _burn(ref self: ComponentState<TContractState>, from: ContractAddress, token_id: u256, value: u256) {
            assert(
                self.ERC1155_balances.read((token_id, from)) >= value,
                Errors::INSUFFICIENT_BALANCE
            );

            self._update_balances(from, Zeroable::zero(), token_id, value);

            self.emit(TransferSingle { from, to: Zeroable::zero(), id: token_id, value });
        }

        /// batch Mints `values` and transfers it to `to`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - `to` is either an account contract or supports the `IERC1155Receiver` interface.
        ///
        /// Emits a `Transfer` event.
        fn _batch_mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            mut token_ids: Span<u256>,
            mut values: Span<u256>
        ) {
            assert(token_ids.len() == values.len(), Errors::INVALID_ARRAY_LENGTH);

            loop {
                if token_ids.len() == 0 {
                    break ();
                }
                let token_id = *token_ids.pop_front().unwrap();
                let value = *values.pop_front().unwrap();

                self._mint(to, token_id, value);
            };

            self
                .emit(
                    TransferBatch { operator: get_caller_address(), from: Zeroable::zero(), to, ids: token_ids, values }
            );
        }

        /// Mints `values` and transfers it to `to`.
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `to` is not the zero address.
        ///
        /// Emits a `Transfer` event.
        fn _mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            value: u256
        ) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);

            self
                .ERC1155_balances
                .write((token_id, to), self.ERC1155_balances.read((token_id, to)) + value);

            self.emit(TransferSingle { from: Zeroable::zero(), to, id: token_id, value });
        }

        /// Safe batch Mints `values` and transfers it to `to`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - `to` is either an account contract or supports the `IERC1155Receiver` interface.
        ///
        /// Emits a `Transfer` event.
        fn _safe_batch_mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            mut token_ids: Span<u256>,
            mut values: Span<u256>,
            data: Span<felt252>
        ) {
            assert(token_ids.len() == values.len(), Errors::INVALID_ARRAY_LENGTH);

            loop {
                if token_ids.len() == 0 {
                    break ();
                }
                let token_id = *token_ids.pop_front().unwrap();
                let value = *values.pop_front().unwrap();

                self._safe_mint(to, token_id, value, data);
            };

            self
                .emit(
                    TransferBatch { operator: get_caller_address(), from: Zeroable::zero(), to, ids: token_ids, values }
            );
        }

        /// Mints `value` if `to` is either an account or `IERC1155Receiver`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - `to` is either an account contract or supports the `IERC1155Receiver` interface.
        ///
        /// Emits a `Transfer` event.
        fn _safe_mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) {
            self._mint(to, token_id, value);
            assert(
                _check_on_ERC1155_received(Zeroable::zero(), to, token_id, value, data),
                Errors::SAFE_MINT_FAILED
            );
        }

        /// Sets the `uri` of `token_id`.
        fn _set_uri(ref self: ComponentState<TContractState>, token_id: u256, uri: felt252) {
            self.ERC1155_uri.write(token_id, uri);
            
            self.emit(URI { value: uri, id: token_id });
        }
    }

    /// Checks if `to` either is an account contract or has registered support
    /// for the `IERC1155Receiver` interface through SRC5. The transaction will
    /// fail if both cases are false.
    fn _check_on_ERC1155_received(
        from: ContractAddress, to: ContractAddress, token_id: u256, value: u256, data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5 { contract_address: to }
            .supports_interface(interface::IERC1155_RECEIVER_ID)) {
            DualCaseERC1155Receiver { contract_address: to }
                .on_erc1155_received(
                    get_caller_address(), from, token_id, value, data
                ) == interface::IERC1155_RECEIVER_ID
        } else {
            DualCaseSRC5 { contract_address: to }.supports_interface(account::interface::ISRC6_ID)
        }
    }

    /// Checks if `to` either is an account contract or has registered support
    /// for the `IERC1155Receiver` interface through SRC5. The transaction will
    /// fail if both cases are false.
    fn _check_on_ERC1155_batch_received(
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5 { contract_address: to }
            .supports_interface(interface::IERC1155_RECEIVER_ID)) {
            DualCaseERC1155Receiver { contract_address: to }
                .on_erc1155_batch_received(
                    get_caller_address(), from, token_ids, values, data
                ) == interface::IERC1155_RECEIVER_ID
        } else {
            DualCaseSRC5 { contract_address: to }.supports_interface(account::interface::ISRC6_ID)
        }
    }
}
