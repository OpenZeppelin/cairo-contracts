mod erc165;
use erc165::ERC165;

mod interface;
use interface::{IERC165_ID, INVALID_ID};
use interface::{IERC165, IERC165Dispatcher, IERC165DispatcherTrait};
use interface::{IERC165Camel, IERC165CamelDispatcher, IERC165CamelDispatcherTrait};

mod dual165;
use dual165::{DualCaseERC165, DualCaseERC165Trait};
