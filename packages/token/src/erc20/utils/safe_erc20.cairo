// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (token/src/erc20/utils/safe_erc20.cairo)

use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::{ContractAddress, get_contract_address};

pub mod Errors {
    pub const SAFE_ERC20_FAILED_OPERATION: felt252 = 'SafeERC20: failed operation';
    pub const SAFE_ERC20_FAILED_DECREASE: felt252 = 'SafeERC20: failed decrease';
}

/// # SafeERC20
///
/// Wrappers around `IERC20Dispatcher` calls that revert with a consistent error message instead of
/// returning `false` on failure, removing the need for callers to write
/// `assert(token.transfer(...), ...)` at every call site.
///
/// The `assert_` prefix reflects what these helpers actually do: they call the underlying ERC20
/// method and panic if it returns `false`. They do not provide additional safety against
/// non-conforming tokens — Cairo's strict ABI deserialization already causes the dispatcher to
/// panic on shape mismatches.
///
/// To use, import the trait into scope and invoke methods directly on an `IERC20Dispatcher`:
///
/// ```cairo
/// use openzeppelin_interfaces::erc20::IERC20Dispatcher;
/// use openzeppelin_token::erc20::utils::SafeERC20DispatcherTrait;
///
/// let token = IERC20Dispatcher { contract_address };
/// token.assert_transfer(recipient, amount);
/// ```
pub trait SafeERC20DispatcherTrait {
    /// Transfers `amount` tokens to `recipient`, reverting on a `false` return value.
    fn assert_transfer(self: IERC20Dispatcher, recipient: ContractAddress, amount: u256);

    /// Transfers `amount` tokens from `sender` to `recipient`, reverting on a `false` return value.
    fn assert_transfer_from(
        self: IERC20Dispatcher, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    );

    /// Increases `spender`'s allowance over the caller-contract's tokens by `added_value`,
    /// reverting on a `false` return value from the underlying `approve` call.
    fn assert_increase_allowance(
        self: IERC20Dispatcher, spender: ContractAddress, added_value: u256,
    );

    /// Decreases `spender`'s allowance over the caller-contract's tokens by `subtracted_value`,
    /// reverting if the current allowance is lower or if the underlying `approve` returns `false`.
    fn assert_decrease_allowance(
        self: IERC20Dispatcher, spender: ContractAddress, subtracted_value: u256,
    );
}

pub impl SafeERC20DispatcherImpl of SafeERC20DispatcherTrait {
    fn assert_transfer(self: IERC20Dispatcher, recipient: ContractAddress, amount: u256) {
        assert(self.transfer(recipient, amount), Errors::SAFE_ERC20_FAILED_OPERATION);
    }

    fn assert_transfer_from(
        self: IERC20Dispatcher, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) {
        assert(self.transfer_from(sender, recipient, amount), Errors::SAFE_ERC20_FAILED_OPERATION);
    }

    fn assert_increase_allowance(
        self: IERC20Dispatcher, spender: ContractAddress, added_value: u256,
    ) {
        let this = get_contract_address();
        let current = self.allowance(this, spender);
        assert(self.approve(spender, current + added_value), Errors::SAFE_ERC20_FAILED_OPERATION);
    }

    fn assert_decrease_allowance(
        self: IERC20Dispatcher, spender: ContractAddress, subtracted_value: u256,
    ) {
        let this = get_contract_address();
        let current = self.allowance(this, spender);
        assert(current >= subtracted_value, Errors::SAFE_ERC20_FAILED_DECREASE);
        assert(
            self.approve(spender, current - subtracted_value), Errors::SAFE_ERC20_FAILED_OPERATION,
        );
    }
}
