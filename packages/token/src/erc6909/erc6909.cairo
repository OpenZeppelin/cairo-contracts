// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc6909/erc6909.cairo)

use core::starknet::{ContractAddress};

/// # ERC6909 Component
///
/// The ERC6909 component provides an implementation of the Minimal Multi-Token standard authored by jtriley.eth
/// See https://eips.ethereum.org/EIPS/eip-6909.
#[starknet::component]
pub mod ERC6909Component {
    use core::integer::BoundedInt;
    use core::num::traits::Zero;
    use openzeppelin::introspection::interface::ISRC5_ID;
    use openzeppelin::token::erc6909::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC6909_balances: LegacyMap<(ContractAddress, u256), u256>,
        ERC6909_allowances: LegacyMap<(ContractAddress, ContractAddress, u256), u256>,
        ERC6909_operators: LegacyMap<(ContractAddress, ContractAddress), bool>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
        OperatorSet: OperatorSet
    }

    /// Emitted when `id` tokens are moved from address `from` to address `to`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Transfer {
        pub caller: ContractAddress,
        #[key]
        pub sender: ContractAddress,
        #[key]
        pub receiver: ContractAddress,
        #[key]
        pub id: u256,
        pub amount: u256,
    }

    /// Emitted when the allowance of a `spender` for an `owner` is set by a call
    /// to `approve` over `id`
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        #[key]
        pub id: u256,
        pub amount: u256
    }

    /// Emitted when `account` enables or disables (`approved`) `spender` to manage
    /// all of its assets.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct OperatorSet {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub approved: bool,
    }

    pub mod Errors {
        pub const INSUFFICIENT_BALANCE: felt252 = 'ERC6909: insufficient balance';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC6909: insufficient allowance';
        pub const TRANSFER_FROM_ZERO: felt252 = 'ERC6909: transfer from 0';
        pub const TRANSFER_TO_ZERO: felt252 = 'ERC6909: transfer to 0';
        pub const MINT_TO_ZERO: felt252 = 'ERC6909: mint to 0';
        pub const BURN_FROM_ZERO: felt252 = 'ERC6909: burn from 0';
        pub const APPROVE_FROM_ZERO: felt252 = 'ERC6909: approve from 0';
        pub const APPROVE_TO_ZERO: felt252 = 'ERC6909: approve to 0';
    }

    //
    // Hooks
    //

    pub trait ERC6909HooksTrait<TContractState> {
        fn before_update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256
        );

        fn after_update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256
        );
    }

    #[embeddable_as(ERC6909Impl)]
    impl ERC6909<
        TContractState, +HasComponent<TContractState>, +ERC6909HooksTrait<TContractState>
    > of interface::IERC6909<ComponentState<TContractState>> {
        /// Returns the amount of `id` tokens owned by `account`.
        fn balance_of(
            self: @ComponentState<TContractState>, owner: ContractAddress, id: u256
        ) -> u256 {
            self.ERC6909_balances.read((owner, id))
        }

        /// Returns the remaining number of `id` tokens that `spender` is
        /// allowed to spend on behalf of `owner` through `transfer_from`.
        /// This is zero by default.
        fn allowance(
            self: @ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            id: u256
        ) -> u256 {
            self.ERC6909_allowances.read((owner, spender, id))
        }

        /// Returns if a spender is approved by an owner as an operator
        fn is_operator(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> bool {
            self.ERC6909_operators.read((owner, spender))
        }

        /// Transfers an amount of an id to a receiver.
        fn transfer(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._transfer(caller, caller, receiver, id, amount);
            true
        }

        /// Transfers an amount of an id from a sender to a receiver.
        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, id, amount);
            self._transfer(caller, sender, receiver, id, amount);
            true
        }

        /// Approves an amount of an id to a spender.
        fn approve(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, id, amount);
            true
        }

        /// Sets or unsets a spender as an operator for the caller.
        fn set_operator(
            ref self: ComponentState<TContractState>, spender: ContractAddress, approved: bool
        ) -> bool {
            let caller = get_caller_address();
            self._set_operator(caller, spender, approved);
            true
        }

        /// Checks if a contract implements an interface.
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            interface_id == interface::IERC6909_ID || interface_id == ISRC5_ID
        }
    }


    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, impl Hooks: ERC6909HooksTrait<TContractState>
    > of InternalTrait<TContractState> {
        /// Creates a `value` amount of tokens and assigns them to `account`.
        ///
        /// Requirements:
        ///
        /// - `receiver` is not the zero address.
        ///
        /// Emits a `Transfer` event with `from` set to the zero address.
        fn mint(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!receiver.is_zero(), Errors::MINT_TO_ZERO);
            self.update(get_caller_address(), Zero::zero(), receiver, id, amount);
        }

        /// Destroys `amount` of tokens from `account`.
        ///
        /// Requirements:
        ///
        /// - `account` is not the zero address.
        /// - `account` must have at least a balance of `amount`.
        ///
        /// Emits a `Transfer` event with `to` set to the zero address.
        fn burn(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!account.is_zero(), Errors::BURN_FROM_ZERO);
            self.update(get_caller_address(), account, Zero::zero(), id, amount);
        }

        /// Transfers an `amount` of tokens from `sender` to `receiver`, or alternatively mints (or burns) 
        /// if `sender` (or `receiver`) is the zero address.
        ///
        /// This function can be extended using the `before_update` and `after_update` hooks. 
        /// The implementation does not keep track of individual token supplies and this logic is left
        /// to the extensions instead.
        ///
        /// Emits a `Transfer` event.
        fn update(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress, // For the `Transfer` event
            sender: ContractAddress, // from
            receiver: ContractAddress, // to
            id: u256,
            amount: u256
        ) {
            Hooks::before_update(ref self, sender, receiver, id, amount);

            let zero_address = Zero::zero();

            if (sender != zero_address) {
                let sender_balance = self.ERC6909_balances.read((sender, id));
                assert(sender_balance >= amount, Errors::INSUFFICIENT_BALANCE);
                self.ERC6909_balances.write((sender, id), sender_balance - amount);
            }

            if (receiver != zero_address) {
                let receiver_balance = self.ERC6909_balances.read((receiver, id));
                self.ERC6909_balances.write((receiver, id), receiver_balance + amount);
            }

            self.emit(Transfer { caller, sender, receiver, id, amount });

            Hooks::after_update(ref self, sender, receiver, id, amount);
        }

        /// Sets or unsets a spender as an operator for the caller.
        fn _set_operator(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            approved: bool
        ) {
            self.ERC6909_operators.write((owner, spender), approved);
            self.emit(OperatorSet { owner, spender, approved });
        }

        /// Updates `sender`s allowance for `spender`  and `id` based on spent `amount`.
        /// Does not update the allowance value in case of infinite allowance or if spender is operator.
        fn _spend_allowance(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            spender: ContractAddress,
            id: u256,
            amount: u256
        ) {
            // In accordance with the transferFrom method, spenders with operator permission are not subject to 
            // allowance restrictions (https://eips.ethereum.org/EIPS/eip-6909).
            if sender != spender && !self.ERC6909_operators.read((sender, spender)) {
                let sender_allowance = self.ERC6909_allowances.read((sender, spender, id));
                assert(sender_allowance >= amount, Errors::INSUFFICIENT_ALLOWANCE);
                if sender_allowance != BoundedInt::max() {
                    self._approve(sender, spender, id, sender_allowance - amount)
                }
            }
        }

        /// Internal method that sets `amount` as the allowance of `spender` over the
        /// `owner`s tokens.
        ///
        /// Requirements:
        ///
        /// - `owner` is not the zero address.
        /// - `spender` is not the zero address.
        ///
        /// Emits an `Approval` event.
        fn _approve(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!owner.is_zero(), Errors::APPROVE_FROM_ZERO);
            assert(!spender.is_zero(), Errors::APPROVE_TO_ZERO);
            self.ERC6909_allowances.write((owner, spender, id), amount);
            self.emit(Approval { owner, spender, id, amount });
        }

        /// Internal method that moves an `amount` of tokens from `sender` to `receiver`.
        ///
        /// Requirements:
        ///
        /// - `sender` is not the zero address.
        /// - `sender` must have at least a balance of `amount`.
        /// - `receiver` is not the zero address.
        ///
        /// Emits a `Transfer` event.
        fn _transfer(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!receiver.is_zero(), Errors::TRANSFER_TO_ZERO);
            self.update(caller, sender, receiver, id, amount);
        }
    }
}

/// An empty implementation of the ERC6909 hooks to be used in basic ERC6909 preset contracts.
pub impl ERC6909HooksEmptyImpl<
    TContractState
> of ERC6909Component::ERC6909HooksTrait<TContractState> {
    fn before_update(
        ref self: ERC6909Component::ComponentState<TContractState>,
        from: ContractAddress,
        recipient: ContractAddress,
        id: u256,
        amount: u256
    ) {}

    fn after_update(
        ref self: ERC6909Component::ComponentState<TContractState>,
        from: ContractAddress,
        recipient: ContractAddress,
        id: u256,
        amount: u256
    ) {}
}
