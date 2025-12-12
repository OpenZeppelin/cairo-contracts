// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.3 (interfaces/src/token/erc3156.cairo)

use starknet::ContractAddress;

/// Interface of the ERC-3156 FlashLender, as defined in
/// https://eips.ethereum.org/EIPS/eip-3156[ERC-3156].
#[starknet::interface]
pub trait IERC3156FlashLender<TState> {
    /// Returns the maximum amount of `token` that can be flash loaned.
    fn max_flash_loan(self: @TState, token: ContractAddress) -> u256;

    /// Returns the fee for borrowing `amount` of `token`.
    fn flash_fee(self: @TState, token: ContractAddress, amount: u256) -> u256;

    /// Initiates a flash loan.
    ///
    /// * `receiver` - The receiver of the tokens and callback.
    /// * `token` - The contract address of the loan currency.
    /// * `amount` - The amount of tokens to loan.
    /// * `data` - Arbitrary data to pass to the receiver.
    ///
    /// Returns true if the loan was successful.
    fn flash_loan(
        ref self: TState,
        receiver: ContractAddress,
        token: ContractAddress,
        amount: u256,
        data: Span<felt252>,
    ) -> bool;
}

/// Interface of the ERC-3156 FlashBorrower, as defined in
/// https://eips.ethereum.org/EIPS/eip-3156[ERC-3156].
#[starknet::interface]
pub trait IERC3156FlashBorrower<TState> {
    /// Receive a flash loan.
    ///
    /// * `initiator` - The initiator of the loan.
    /// * `token` - The loan currency.
    /// * `amount` - The amount of tokens lent.
    /// * `fee` - The additional amount of tokens to repay.
    /// * `data` - Arbitrary data structure, intended to contain user-defined parameters.
    ///
    /// Returns the felt252 pedersen hash of "ERC3156FlashBorrower.onFlashLoan"
    fn on_flash_loan(
        ref self: TState,
        initiator: ContractAddress,
        token: ContractAddress,
        amount: u256,
        fee: u256,
        data: Span<felt252>,
    ) -> felt252;
}
