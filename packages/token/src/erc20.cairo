pub mod dual20;
pub mod erc20;
pub mod interface;

pub use erc20::{ERC20Component, ERC20HooksEmptyImpl};
pub use interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
