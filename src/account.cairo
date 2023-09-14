mod account;
mod dual_account;
mod interface;

use account::Account;
use interface::AccountABIDispatcher;
use interface::AccountABIDispatcherTrait;
use interface::AccountCamelABIDispatcher;
use interface::AccountCamelABIDispatcherTrait;

const TRANSACTION_VERSION: felt252 = 1;

// 2**128 + TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457;
