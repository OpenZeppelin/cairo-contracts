// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0 (token/src/erc6909/erc6909.cairo)

/// # ERC6909 Component
///
/// The ERC6909 component provides an implementation of the Minimal Multi-Token standard described in https://eips.ethereum.org/EIPS/eip-6909.
#[starknet::component]
pub mod ERC6909Component {
    use core::num::traits::{Bounded, Zero};
    use openzeppelin_interfaces::erc6909 as interface;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::{
        InternalTrait as SRC5InternalTrait, SRC5Impl,
    };
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        ERC6909_balances: Map<(ContractAddress, u256), u256>,
        ERC6909_allowances: Map<(ContractAddress, ContractAddress, u256), u256>,
        ERC6909_operators: Map<(ContractAddress, ContractAddress), bool>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
        OperatorSet: OperatorSet,
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
        pub amount: u256,
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
        pub const INVALID_APPROVER: felt252 = 'ERC6909: invalid approver';
        pub const INVALID_RECEIVER: felt252 = 'ERC6909: invalid receiver';
        pub const INVALID_SENDER: felt252 = 'ERC6909: invalid sender';
        pub const INVALID_SPENDER: felt252 = 'ERC6909: invalid spender';
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
            amount: u256,
        ) {}

        fn after_update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256,
        ) {}
    }

    
    //
    // External
    //
    
    #[embeddable_as(ERC6909Impl)]
    impl ERC6909<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of interface::IERC6909<ComponentState<TContractState>> {
        /// Returns the amount of `id` tokens owned by `account`.
        fn balance_of(
            self: @ComponentState<TContractState>, owner: ContractAddress, id: u256,
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
            id: u256,
        ) -> u256 {
            self.ERC6909_allowances.read((owner, spender, id))
        }

        /// Returns if a spender is approved by an owner as an operator
        fn is_operator(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress,
        ) -> bool {
            self.ERC6909_operators.read((owner, spender))
        }

        /// Transfers an amount of an id to a receiver.
        fn transfer(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            id: u256,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            self._transfer(caller, receiver, id, amount);
            true
        }

        /// Transfers an amount of an id from a sender to a receiver.
        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, id, amount);
            self._transfer(sender, receiver, id, amount);
            true
        }

        /// Approves an amount of an id to a spender.
        fn approve(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            id: u256,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, id, amount);
            true
        }

        /// Sets or unsets a spender as an operator for the caller.
        fn set_operator(
            ref self: ComponentState<TContractState>, spender: ContractAddress, approved: bool,
        ) -> bool {
            let caller = get_caller_address();
            self._set_operator(caller, spender, approved);
            true
        }
    }


    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        impl Hooks: ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering the supported interfaces
        /// This should only be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC6909_ID);
        }

        /// Creates a `value` amount of tokens and assigns them to `account`.
        ///
        /// Requirements:
        ///
        /// - `receiver` is not the zero address.
        ///
        /// Emits a `Transfer` event with `from` set to the zero address.
        fn _mint(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            assert(receiver.is_non_zero(), Errors::INVALID_RECEIVER);
            self._update(Zero::zero(), receiver, id, amount);
        }

        /// Destroys `amount` of tokens from `account`.
        ///
        /// Requirements:
        ///
        /// - `account` is not the zero address.
        /// - `account` must have at least a balance of `amount`.
        ///
        /// Emits a `Transfer` event with `to` set to the zero address.
        fn _burn(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            assert(account.is_non_zero(), Errors::INVALID_SENDER);
            self._update(account, Zero::zero(), id, amount);
        }

        /// Transfers an `amount` of tokens from `sender` to `receiver`, or alternatively mints (or
        /// burns) if `sender` (or `receiver`) is the zero address.
        ///
        /// This function can be extended using the `before_update` and `after_update` hooks.
        /// The implementation does not keep track of individual token supplies and this logic is
        /// left to the extensions instead.
        ///
        /// Emits a `Transfer` event.
        fn _update(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            Hooks::before_update(ref self, sender, receiver, id, amount);

            if (sender.is_non_zero()) {
                let sender_balance = self.ERC6909_balances.read((sender, id));
                assert(sender_balance >= amount, Errors::INSUFFICIENT_BALANCE);
                self.ERC6909_balances.write((sender, id), sender_balance - amount);
            }

            if (receiver.is_non_zero()) {
                let receiver_balance = self.ERC6909_balances.read((receiver, id));
                self.ERC6909_balances.write((receiver, id), receiver_balance + amount);
            }

            self.emit(Transfer { caller: get_caller_address(), sender, receiver, id, amount });

            Hooks::after_update(ref self, sender, receiver, id, amount);
        }

        /// Sets or unsets a spender as an operator for the caller.
        fn _set_operator(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            approved: bool,
        ) {
            self.ERC6909_operators.write((owner, spender), approved);
            self.emit(OperatorSet { owner, spender, approved });
        }

        /// Updates `sender`'s allowance for `spender`  and `id` based on spent `amount`.
        /// Does not update the allowance value in case of infinite allowance or if spender is
        /// operator.
        fn _spend_allowance(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            // In accordance with the transferFrom method, spenders with operator permission are not
            // subject to allowance restrictions (https://eips.ethereum.org/EIPS/eip-6909).
            if owner != spender && !self.ERC6909_operators.read((owner, spender)) {
                let sender_allowance = self.ERC6909_allowances.read((owner, spender, id));

                if sender_allowance != Bounded::MAX {
                    assert(sender_allowance >= amount, Errors::INSUFFICIENT_ALLOWANCE);
                    self._approve(owner, spender, id, sender_allowance - amount)
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
            amount: u256,
        ) {
            assert(owner.is_non_zero(), Errors::INVALID_APPROVER);
            assert(spender.is_non_zero(), Errors::INVALID_SPENDER);
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
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            assert(sender.is_non_zero(), Errors::INVALID_SENDER);
            assert(receiver.is_non_zero(), Errors::INVALID_RECEIVER);
            self._update(sender, receiver, id, amount);
        }
    }
}

/// An empty implementation of the ERC6909 hooks to be used in basic ERC6909 preset contracts.
pub impl ERC6909HooksEmptyImpl<
    TContractState,
> of ERC6909Component::ERC6909HooksTrait<TContractState> {}
