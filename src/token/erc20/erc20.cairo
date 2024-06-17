// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc20/erc20.cairo)

use starknet::ContractAddress;

/// # ERC20 Component
///
/// The ERC20 component provides an implementation of the IERC20 interface as well as
/// non-standard implementations that can be used to create an ERC20 contract. This
/// component is agnostic regarding how tokens are created, which means that developers
/// must create their own token distribution mechanism.
/// See [the documentation](https://docs.openzeppelin.com/contracts-cairo/0.14.0/guides/erc20-supply)
/// for examples.
#[starknet::component]
pub mod ERC20Component {
    use core::integer::BoundedInt;
    use core::num::traits::Zero;
    use openzeppelin::token::erc20::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC20_name: ByteArray,
        ERC20_symbol: ByteArray,
        ERC20_total_supply: u256,
        ERC20_balances: LegacyMap<ContractAddress, u256>,
        ERC20_allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    /// Emitted when tokens are moved from address `from` to address `to`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Transfer {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub value: u256
    }

    /// Emitted when the allowance of a `spender` for an `owner` is set by a call
    /// to `approve`. `value` is the new allowance.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256
    }

    pub mod Errors {
        pub const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
        pub const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
        pub const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
        pub const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
        pub const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
        pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
        pub const INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';
    }

    //
    // Hooks
    //

    pub trait ERC20HooksTrait<TContractState> {
        fn before_update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        );

        fn after_update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        );
    }

    //
    // External
    //

    #[embeddable_as(ERC20Impl)]
    impl ERC20<
        TContractState, +HasComponent<TContractState>, +ERC20HooksTrait<TContractState>
    > of interface::IERC20<ComponentState<TContractState>> {
        /// Returns the value of tokens in existence.
        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            self.ERC20_total_supply.read()
        }

        /// Returns the amount of tokens owned by `account`.
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.ERC20_balances.read(account)
        }

        /// Returns the remaining number of tokens that `spender` is
        /// allowed to spend on behalf of `owner` through `transfer_from`.
        /// This is zero by default.
        /// This value changes when `approve` or `transfer_from` are called.
        fn allowance(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.ERC20_allowances.read((owner, spender))
        }

        /// Moves `amount` tokens from the caller's token balance to `to`.
        ///
        /// Requirements:
        ///
        /// - `recipient` is not the zero address.
        /// - The caller has a balance of at least `amount`.
        ///
        /// Emits a `Transfer` event.
        fn transfer(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, amount: u256
        ) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        /// Moves `amount` tokens from `from` to `to` using the allowance mechanism.
        /// `amount` is then deducted from the caller's allowance.
        ///
        /// Requirements:
        ///
        /// - `sender` is not the zero address.
        /// - `sender` must have a balance of at least `amount`.
        /// - `recipient` is not the zero address.
        /// - The caller has an allowance of `sender`'s tokens of at least `amount`.
        ///
        /// Emits a `Transfer` event.
        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        /// Sets `amount` as the allowance of `spender` over the caller’s tokens.
        ///
        /// Requirements:
        ///
        /// - `spender` is not the zero address.
        ///
        /// Emits an `Approval` event.
        fn approve(
            ref self: ComponentState<TContractState>, spender: ContractAddress, amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }
    }

    #[embeddable_as(ERC20MetadataImpl)]
    impl ERC20Metadata<
        TContractState, +HasComponent<TContractState>, +ERC20HooksTrait<TContractState>
    > of interface::IERC20Metadata<ComponentState<TContractState>> {
        /// Returns the name of the token.
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC20_name.read()
        }

        /// Returns the ticker symbol of the token, usually a shorter version of the name.
        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC20_symbol.read()
        }

        /// Returns the number of decimals used to get its user representation.
        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            18
        }
    }

    /// Adds camelCase support for `IERC20`.
    #[embeddable_as(ERC20CamelOnlyImpl)]
    impl ERC20CamelOnly<
        TContractState, +HasComponent<TContractState>, +ERC20HooksTrait<TContractState>
    > of interface::IERC20CamelOnly<ComponentState<TContractState>> {
        fn totalSupply(self: @ComponentState<TContractState>) -> u256 {
            ERC20::total_supply(self)
        }

        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            ERC20::balance_of(self, account)
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            ERC20::transfer_from(ref self, sender, recipient, amount)
        }
    }

    #[embeddable_as(ERC20MixinImpl)]
    impl ERC20Mixin<
        TContractState, +HasComponent<TContractState>, +ERC20HooksTrait<TContractState>
    > of interface::ERC20ABI<ComponentState<TContractState>> {
        // IERC20
        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            ERC20::total_supply(self)
        }

        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            ERC20::balance_of(self, account)
        }

        fn allowance(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            ERC20::allowance(self, owner, spender)
        }

        fn transfer(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, amount: u256
        ) -> bool {
            ERC20::transfer(ref self, recipient, amount)
        }

        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            ERC20::transfer_from(ref self, sender, recipient, amount)
        }

        fn approve(
            ref self: ComponentState<TContractState>, spender: ContractAddress, amount: u256
        ) -> bool {
            ERC20::approve(ref self, spender, amount)
        }

        // IERC20Metadata
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            ERC20Metadata::name(self)
        }

        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            ERC20Metadata::symbol(self)
        }

        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            ERC20Metadata::decimals(self)
        }

        // IERC20CamelOnly
        fn totalSupply(self: @ComponentState<TContractState>) -> u256 {
            ERC20CamelOnly::totalSupply(self)
        }

        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            ERC20CamelOnly::balanceOf(self, account)
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            ERC20CamelOnly::transferFrom(ref self, sender, recipient, amount)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, impl Hooks: ERC20HooksTrait<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by setting the token name and symbol.
        /// To prevent reinitialization, this should only be used inside of a contract's constructor.
        fn initializer(
            ref self: ComponentState<TContractState>, name: ByteArray, symbol: ByteArray
        ) {
            self.ERC20_name.write(name);
            self.ERC20_symbol.write(symbol);
        }

        /// Creates a `value` amount of tokens and assigns them to `account`.
        ///
        /// Requirements:
        ///
        /// - `recipient` is not the zero address.
        ///
        /// Emits a `Transfer` event with `from` set to the zero address.
        fn mint(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, amount: u256
        ) {
            assert(!recipient.is_zero(), Errors::MINT_TO_ZERO);
            self.update(Zero::zero(), recipient, amount);
        }

        /// Destroys `amount` of tokens from `account`.
        ///
        /// Requirements:
        ///
        /// - `account` is not the zero address.
        /// - `account` must have at least a balance of `amount`.
        ///
        /// Emits a `Transfer` event with `to` set to the zero address.
        fn burn(ref self: ComponentState<TContractState>, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), Errors::BURN_FROM_ZERO);
            self.update(account, Zero::zero(), amount);
        }


        /// Transfers an `amount` of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or `to`) is
        /// the zero address.
        ///
        /// NOTE: This function can be extended using the `ERC20HooksTrait`, to add
        /// functionality before and/or after the transfer, mint, or burn.
        ///
        /// Emits a `Transfer` event.
        fn update(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            Hooks::before_update(ref self, from, to, amount);

            let zero_address = Zero::zero();
            if (from == zero_address) {
                let total_supply = self.ERC20_total_supply.read();
                self.ERC20_total_supply.write(total_supply + amount);
            } else {
                let from_balance = self.ERC20_balances.read(from);
                assert(from_balance >= amount, Errors::INSUFFICIENT_BALANCE);
                self.ERC20_balances.write(from, from_balance - amount);
            }

            if (to == zero_address) {
                let total_supply = self.ERC20_total_supply.read();
                self.ERC20_total_supply.write(total_supply - amount);
            } else {
                let to_balance = self.ERC20_balances.read(to);
                self.ERC20_balances.write(to, to_balance + amount);
            }

            self.emit(Transfer { from, to, value: amount });

            Hooks::after_update(ref self, from, to, amount);
        }

        /// Internal method that moves an `amount` of tokens from `from` to `to`.
        ///
        /// Requirements:
        ///
        /// - `sender` is not the zero address.
        /// - `sender` must have at least a balance of `amount`.
        /// - `recipient` is not the zero address.
        ///
        /// Emits a `Transfer` event.
        fn _transfer(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!recipient.is_zero(), Errors::TRANSFER_TO_ZERO);
            self.update(sender, recipient, amount);
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
            amount: u256
        ) {
            assert(!owner.is_zero(), Errors::APPROVE_FROM_ZERO);
            assert(!spender.is_zero(), Errors::APPROVE_TO_ZERO);
            self.ERC20_allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        /// Updates `owner`s allowance for `spender` based on spent `amount`.
        /// Does not update the allowance value in case of infinite allowance.
        ///
        /// Requirements:
        ///
        /// - `spender` must have at least an allowance of `amount` from `owner`.
        ///
        /// Possibly emits an `Approval` event.
        fn _spend_allowance(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256
        ) {
            let current_allowance = self.ERC20_allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                assert(current_allowance >= amount, Errors::INSUFFICIENT_ALLOWANCE);
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}

/// An empty implementation of the ERC20 hooks to be used in basic ERC20 preset contracts.
pub impl ERC20HooksEmptyImpl<TContractState> of ERC20Component::ERC20HooksTrait<TContractState> {
    fn before_update(
        ref self: ERC20Component::ComponentState<TContractState>,
        from: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    ) {}

    fn after_update(
        ref self: ERC20Component::ComponentState<TContractState>,
        from: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    ) {}
}
