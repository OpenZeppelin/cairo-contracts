// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (token/erc721/extensions/erc721_enumerable/erc721_enumerable.cairo)

/// # ERC721Enumerable Component
///
///
#[starknet::component]
mod ERC721EnumerableComponent {
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component::ERC721HooksTrait;
    use openzeppelin::token::erc721::ERC721Component::ERC721Impl;
    use openzeppelin::token::erc721::ERC721Component::InternalImpl as ERC721InternalImpl;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::extensions::erc721_enumerable::interface::{
        IERC721Enumerable, IERC721EnumerableCamel
    };
    use openzeppelin::token::erc721::extensions::erc721_enumerable::interface;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        ERC721Enumerable_owned_tokens: LegacyMap<(ContractAddress, u256), u256>,
        ERC721Enumerable_owned_tokens_index: LegacyMap<u256, u256>,
        ERC721Enumerable_all_tokens_len: u256,
        ERC721Enumerable_all_tokens: LegacyMap<u256, u256>,
        ERC721Enumerable_all_tokens_index: LegacyMap<u256, u256>
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {}

    mod Errors {
        const OUT_OF_BOUNDS_INDEX: felt252 = 'ERC721Enum: out of bounds index';
    }

    #[embeddable_as(ERC721EnumerableImpl)]
    impl ERC721Enumerable<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721Enumerable<ComponentState<TContractState>> {
        /// Returns the total amount of tokens stored by the contract.
        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            self.ERC721Enumerable_all_tokens_len.read()
        }

        /// Returns a token id at a given `index` of all the tokens stored by the contract.
        /// Use along with `total_supply` to enumerate all tokens.
        ///
        /// Requirements:
        ///
        /// - `index` is less than the total token supply.
        fn token_by_index(self: @ComponentState<TContractState>, index: u256) -> u256 {
            assert(index < self.total_supply(), Errors::OUT_OF_BOUNDS_INDEX);
            assert(index < self.total_supply(), Errors::OUT_OF_BOUNDS_INDEX);
            self.ERC721Enumerable_all_tokens.read(index)
        }

        /// Returns the token id owned by `owner` at a given `index` of its token list.
        /// Use along with `ERC721::balance_of` to enumerate all of `owner`'s tokens.
        ///
        /// Requirements:
        ///
        /// - `index` is less than `owner`'s token balance.
        /// - `owner` is not the zero address.
        fn token_of_owner_by_index(
            self: @ComponentState<TContractState>, owner: ContractAddress, index: u256
        ) -> u256 {
            let erc721_component = get_dep_component!(self, ERC721);
            assert(index < erc721_component.balance_of(owner), Errors::OUT_OF_BOUNDS_INDEX);
            self.ERC721Enumerable_owned_tokens.read((owner, index))
        }
    }

    /// Adds camelCase support for `IERC721Enumerable`.
    #[embeddable_as(ERC721EnumerableCamelImpl)]
    impl ERC721EnumerableCamel<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721EnumerableCamel<ComponentState<TContractState>> {
        fn totalSupply(self: @ComponentState<TContractState>) -> u256 {
            self.total_supply()
        }

        fn tokenOfOwnerByIndex(
            self: @ComponentState<TContractState>, owner: ContractAddress, index: u256
        ) -> u256 {
            self.token_of_owner_by_index(owner, index)
        }

        fn tokenByIndex(self: @ComponentState<TContractState>, index: u256) -> u256 {
            self.token_by_index(index)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by declaring support for the `IERC721Enumerable`
        /// interface id.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC721ENUMERABLE_ID);
        }

        /// Updates the ownership and token-tracking data structures.
        ///
        /// When a token is minted (or burned), `token_id` is added to (or removed from)
        /// the token-tracking structures.
        ///
        /// When a token is transferred, the ownership-tracking data structures reflect
        /// the change in ownership of `token_id`.
        ///
        /// This must be added to the implementing contract's `ERC721HooksTrait::before_update` hook.
        fn before_update(
            ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let previous_owner = erc721_component._owner_of(token_id);
            let zero_address = Zeroable::zero();

            if previous_owner == zero_address {
                PrivateImpl::_add_token_to_all_tokens_enumeration(ref self, token_id);
            } else if previous_owner != to {
                PrivateImpl::_remove_token_from_owner_enumeration(
                    ref self, previous_owner, token_id
                );
            }

            if to == zero_address {
                PrivateImpl::_remove_token_from_all_tokens_enumeration(ref self, token_id);
            } else if previous_owner != to {
                PrivateImpl::_add_token_to_owner_enumeration(ref self, to, token_id);
            }
        }
    }

    #[generate_trait]
    impl PrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of PrivateTrait<TContractState> {
        /// Adds token to this extension's ownership-tracking data structures.
        fn _add_token_to_owner_enumeration(
            ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256
        ) {
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            let len = erc721_component.balance_of(to);
            self.ERC721Enumerable_owned_tokens.write((to, len), token_id);
            self.ERC721Enumerable_owned_tokens_index.write(token_id, len);
        }

        /// Adds token to this extension's token-tracking data structures.
        fn _add_token_to_all_tokens_enumeration(
            ref self: ComponentState<TContractState>, token_id: u256
        ) {
            let supply = self.total_supply();
            self.ERC721Enumerable_all_tokens_index.write(token_id, supply);
            self.ERC721Enumerable_all_tokens.write(supply, token_id);
            self.ERC721Enumerable_all_tokens_len.write(supply + 1);
        }

        /// Removes a token from this extension's ownership-tracking data structures.
        ///
        /// This has 0(1) time complexity but alters the indexed order of owned-tokens by
        /// swapping `token_id` and the index thereof with the last token id and the index
        /// thereof.
        fn _remove_token_from_owner_enumeration(
            ref self: ComponentState<TContractState>, from: ContractAddress, token_id: u256
        ) {
            let erc721_component = get_dep_component!(@self, ERC721);
            let last_token_index = erc721_component.balance_of(from) - 1;
            let this_token_index = self.ERC721Enumerable_owned_tokens_index.read(token_id);

            // To prevent a gap in the token indexing of `from`, we store the last token
            // in the index of the token to delete and then remove the last slot (swap and pop).
            // When `token_id` is the last token, the swap operation is unnecessary
            if this_token_index != last_token_index {
                let last_token_id = self
                    .ERC721Enumerable_owned_tokens
                    .read((from, last_token_index));
                // Set `token_id` index to point to the last token id
                self.ERC721Enumerable_owned_tokens.write((from, this_token_index), last_token_id);
                // Set the last token id index to point to `token_id`'s index position
                self.ERC721Enumerable_owned_tokens_index.write(last_token_id, this_token_index);
            }

            // Remove `token_id` from last token index position
            self.ERC721Enumerable_owned_tokens.write((from, last_token_index), 0);
        }

        /// Removes `token_id` from this extension's token-tracking data structures.
        ///
        /// This has 0(1) time complexity but alters the indexed order by swapping
        /// `token_id` and the index thereof with the last token id and the index thereof.
        fn _remove_token_from_all_tokens_enumeration(
            ref self: ComponentState<TContractState>, token_id: u256
        ) {
            let last_token_index = self.total_supply() - 1;
            let this_token_index = self.ERC721Enumerable_all_tokens_index.read(token_id);
            let last_token_id = self.ERC721Enumerable_all_tokens.read(last_token_index);

            // Set last token index to zero
            self.ERC721Enumerable_all_tokens.write(last_token_index, 0);
            // Set `token_id` index to 0
            self.ERC721Enumerable_all_tokens_index.write(token_id, 0);
            // Remove one from total supply
            self.ERC721Enumerable_all_tokens_len.write(last_token_index);

            // When the token to delete is the last token, the swap operation is unnecessary. However,
            // since this occurs rarely (when the last minted token is burnt), we still do the swap
            // which avoids the additional expense of including an `if` statement
            self.ERC721Enumerable_all_tokens_index.write(last_token_id, this_token_index);
            self.ERC721Enumerable_all_tokens.write(this_token_index, last_token_id);
        }
    }
}
