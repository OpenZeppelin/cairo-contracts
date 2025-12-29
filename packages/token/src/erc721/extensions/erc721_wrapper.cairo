// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0
// (token/src/erc721/extensions/erc721_wrapper.cairo)

/// # ERC721Wrapper Component
///
/// Users can deposit and withdraw "underlying tokens" and receive a wrapped token with the
/// matching token id. This is useful in conjunction with other modules. For example, combining
/// this wrapping mechanism with the ERC721VotesComponent will allow the wrapping of an existing
/// "basic" ERC-721 into a governance token.
#[starknet::component]
pub mod ERC721WrapperComponent {
    use core::num::traits::Zero;
    use openzeppelin_interfaces::erc721 as interface;
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_interfaces::token::erc721::{IERC721ReceiverMut, IERC721Wrapper};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::erc721::ERC721Component;
    use crate::erc721::ERC721Component::InternalImpl as ERC721InternalImpl;

    #[storage]
    pub struct Storage {
        pub ERC721Wrapper_underlying: ContractAddress,
    }

    pub mod Errors {
        pub const INVALID_UNDERLYING_ADDRESS: felt252 = 'Wrapper: invalid underlying';
        pub const UNSUPPORTED_TOKEN: felt252 = 'Wrapper: unsupported token';
        pub const INCORRECT_OWNER: felt252 = 'Wrapper: incorrect owner';
    }

    //
    // External
    //

    #[embeddable_as(ERC721WrapperImpl)]
    impl ERC721Wrapper<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC721Wrapper<ComponentState<TContractState>> {
        /// Returns the address of the underlying token used for the wrapper.
        fn underlying(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ERC721Wrapper_underlying.read()
        }

        /// Deposits underlying tokens and mints wrapped tokens with matching token ids to
        /// `receiver`.
        fn deposit_for(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            token_ids: Span<u256>,
        ) -> bool {
            let caller = starknet::get_caller_address();
            let this = starknet::get_contract_address();
            let underlying = self.underlying();
            let token = IERC721Dispatcher { contract_address: underlying };
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            let data = array![].span();

            for token_id in token_ids {
                // This is an "unsafe" transfer that doesn't call any hook on the receiver. With
                // underlying() being trusted (by design of this contract) and no other contracts
                // expected to be called from there, reentrancy should be safe.
                token.transfer_from(caller, this, *token_id);
                erc721_component.safe_mint(receiver, *token_id, data);
            }
            true
        }

        /// Burns wrapped tokens from the caller and withdraws underlying tokens to `receiver`.
        fn withdraw_to(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            token_ids: Span<u256>,
        ) -> bool {
            let caller = starknet::get_caller_address();
            let this = starknet::get_contract_address();
            let underlying = self.underlying();
            let token = IERC721Dispatcher { contract_address: underlying };
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            let data = array![].span();

            for token_id in token_ids {
                // Setting an "auth" arguments enables the `_check_authorized` check which verifies
                // that the token exists (owner != 0). Therefore, it is not needed to verify that
                // the return value is not 0 here.
                erc721_component.update(Zero::zero(), *token_id, caller);
                // Checks were already performed at this point, and there's no way to retake
                // ownership or approval from the wrapped token id after this point.
                token.safe_transfer_from(this, receiver, *token_id, data);
            }
            true
        }
    }

    #[embeddable_as(ERC721WrapperReceiverImpl)]
    impl ERC721WrapperReceiver<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC721ReceiverMut<ComponentState<TContractState>> {
        /// Accepts safe transfers of the underlying token and mints the wrapped token.
        fn on_erc721_received(
            ref self: ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) -> felt252 {
            let caller = starknet::get_caller_address();
            assert(caller == self.underlying(), Errors::UNSUPPORTED_TOKEN);

            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            // TODO!: Should mint to from or operator?
            erc721_component.safe_mint(from, token_id, data);

            interface::IERC721_RECEIVER_ID
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Sets the underlying token address and declares support for IERC721Receiver.
        fn initializer(ref self: ComponentState<TContractState>, underlying: ContractAddress) {
            let this = starknet::get_contract_address();
            assert(underlying.is_non_zero(), Errors::INVALID_UNDERLYING_ADDRESS);
            assert(underlying != this, Errors::INVALID_UNDERLYING_ADDRESS);
            self.ERC721Wrapper_underlying.write(underlying);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC721_RECEIVER_ID);
        }

        /// Mints a wrapped token to cover an underlying token that was transferred by mistake.
        fn recover(
            ref self: ComponentState<TContractState>, account: ContractAddress, token_id: u256,
        ) -> u256 {
            let underlying = self.underlying();
            let this = starknet::get_contract_address();
            let token = IERC721Dispatcher { contract_address: underlying };
            let owner = token.owner_of(token_id);
            assert(owner == this, Errors::INCORRECT_OWNER);

            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            let data = array![].span();
            erc721_component.safe_mint(account, token_id, data);
            token_id
        }
    }
}
