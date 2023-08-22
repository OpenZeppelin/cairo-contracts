//! SPDX-License-Identifier: MIT
//! OpenZeppelin Contracts for Cairo v0.7.0 (token/erc20/erc20.cairo)
//!
//! # ERC20 Contract and Implementation
//!
//! # Examples
//!
//! How to extend the ERC20 contract:
//! ```
//! #[starknet::contract]
//! mod MyToken {
//!   use openzeppelin::token::erc20::ERC20;
//!   use starknet::ContractAddress;
//!
//!    #[storage]
//!    struct Storage {}
//!
//!    #[constructor]
//!    fn constructor(
//!        ref self: ContractState,
//!        initial_supply: u256,
//!        recipient: ContractAddress
//!    ) {
//!        let name = 'MyToken';
//!        let symbol = 'MTK';
//!        let mut unsafe_state = ERC20::unsafe_new_contract_state();
//!        ERC20::InternalImpl::initializer(ref unsafe_state, name, symbol);
//!        ERC20::InternalImpl::_mint(ref unsafe_state, recipient, initial_supply);
//!    }
//!
//!    // Define methods that extend the ERC20 standard contract.
//!    #[external(v0)]
//!    fn name(self: @ContractState) -> felt252 {
//!        let unsafe_state = ERC20::unsafe_new_contract_state();
//!        ERC20::ERC20Impl::name(@unsafe_state)
//!    }
//!
//!    ...
//!
//! }
//! ```
#[starknet::contract]
mod ERC20 {
    use integer::BoundedInt;
    use openzeppelin::token::erc20::interface::IERC20;
    use openzeppelin::token::erc20::interface::IERC20CamelOnly;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _total_supply: u256,
        _balances: LegacyMap<ContractAddress, u256>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    /// Emitted when tokens are moved from address `from` to address `to`.
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    }

    /// Emitted when the allowance of a `spender` for an `owner` is set by a call
    /// to [approve](approve). `value` is the new allowance.
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256
    }

    /// Initializes the state of the ERC20 contract. This includes setting the
    /// initial supply of tokens as well as the recipient of the initial supply.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.initializer(name, symbol);
        self._mint(recipient, initial_supply);
    }

    //
    // External
    //

    #[external(v0)]
    impl ERC20Impl of IERC20<ContractState> {
        /// Returns the name of the token.
        fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }

        /// Returns the ticker symbol of the token, usually a shorter version of the name.
        fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }

        /// Returns the number of decimals used to get its user representation.
        ///
        /// For example, if `decimals` equals `2`, a balance of `505` tokens should
        /// be displayed to a user as `5.05` (`505 / 10 ** 2`).
        ///
        /// Tokens usually opt for a value of 18, imitating the relationship between
        /// Ether and Wei. This is the default value returned by this function, unless
        /// a custom implementation is used.
        ///
        /// NOTE: This information is only used for _display_ purposes: it in
        /// no way affects any of the arithmetic of the contract.
        fn decimals(self: @ContractState) -> u8 {
            18
        }

        /// Returns the value of tokens in existence.
        fn total_supply(self: @ContractState) -> u256 {
            self._total_supply.read()
        }

        /// Returns the amount of tokens owned by `account`.
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self._balances.read(account)
        }

        /// Returns the remaining number of tokens that `spender` will be
        /// allowed to spend on behalf of `owner` through [transfer_from](transfer_from).
        /// This is zero by default.
        /// This value changes when [approve](approve) or [transfer_from](transfer_from)
        /// are called.
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self._allowances.read((owner, spender))
        }

        /// Moves `amount` tokens from the caller's token balance to `to`.
        /// Emits a [Transfer](Transfer) event.
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        /// Moves `amount` tokens from `from` to `to` using the allowance mechanism.
        /// `amount` is then deducted from the caller's allowance.
        /// Emits a [Transfer](Transfer) event.
        fn transfer_from(
            ref self: ContractState,
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
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }
    }

    #[external(v0)]
    impl ERC20CamelOnlyImpl of IERC20CamelOnly<ContractState> {
        /// Camel case support.
        /// See [total_supply](total-supply).
        fn totalSupply(self: @ContractState) -> u256 {
            ERC20Impl::total_supply(self)
        }

        /// Camel case support.
        /// See [balance_of](balance_of).
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            ERC20Impl::balance_of(self, account)
        }

        /// Camel case support.
        /// See [transfer_from](transfer_from).
        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            ERC20Impl::transfer_from(ref self, sender, recipient, amount)
        }
    }

    /// Atomically increases the allowance granted to `spender` by the caller.
    /// Emits an [Approval](Approval) event indicating the updated allowance.
    #[external(v0)]
    fn increase_allowance(
        ref self: ContractState, spender: ContractAddress, added_value: u256
    ) -> bool {
        self._increase_allowance(spender, added_value)
    }

    /// Camel case support.
    /// See [increase_allowance](increase_allowance).
    #[external(v0)]
    fn increaseAllowance(
        ref self: ContractState, spender: ContractAddress, addedValue: u256
    ) -> bool {
        increase_allowance(ref self, spender, addedValue)
    }

    /// Atomically decreases the allowance granted to `spender` by the caller.
    /// Emits an [Approval](Approval) event indicating the updated allowance.
    #[external(v0)]
    fn decrease_allowance(
        ref self: ContractState, spender: ContractAddress, subtracted_value: u256
    ) -> bool {
        self._decrease_allowance(spender, subtracted_value)
    }

    /// Camel case support.
    /// See [decrease_allowance](decrease_allowance).
    #[external(v0)]
    fn decreaseAllowance(
        ref self: ContractState, spender: ContractAddress, subtractedValue: u256
    ) -> bool {
        decrease_allowance(ref self, spender, subtractedValue)
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Initializes the contract by setting the token name and symbol.
        /// This should be used inside of the contract's constructor.
        fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252) {
            self._name.write(name_);
            self._symbol.write(symbol_);
        }

        /// Internal method for the external [increase_allowance](increase_allowance).
        /// Emits an [Approval](Approval) event indicating the updated allowance.
        fn _increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self._allowances.read((caller, spender)) + added_value);
            true
        }

        /// Internal method for the external [decrease_allowance](decrease_allowance).
        /// Emits an [Approval](Approval) event indicating the updated allowance.
        fn _decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self
                ._approve(
                    caller, spender, self._allowances.read((caller, spender)) - subtracted_value
                );
            true
        }

        /// Creates a `value` amount of tokens and assigns them to `account`, by
        /// transferring it from address(0).
        /// Emits a [Transfer](Transfer) event with `from` set to the zero address.
        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            self._total_supply.write(self._total_supply.read() + amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        /// Destroys a `value` amount of tokens from `account`, by transferring it
        /// to address(0).
        /// Emits a [Transfer](Transfer) event with `to` set to the zero address.
        fn _burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self._total_supply.write(self._total_supply.read() - amount);
            self._balances.write(account, self._balances.read(account) - amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        /// Internal method that sets `amount` as the allowance of `spender` over the
        /// `owner`s tokens.
        /// Emits an [Approval](Approval) event.
        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self._allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        /// Internal method that moves an `amount` of tokens from `from` to `to`.
        /// Emits a [Transfer](Transfer) event.
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self._balances.write(sender, self._balances.read(sender) - amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        /// Updates `owner`s allowance for `spender` based on spent `amount`.
        /// Does not update the allowance value in case of infinite allowance.
        /// Possibly emits an [Approval](Approval) event.
        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self._allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}
