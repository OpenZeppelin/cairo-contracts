use openzeppelin_test_common::mocks::get_info::{IGetInfoDispatcher, IGetInfoDispatcherTrait};
use openzeppelin_testing as utils;
use snforge_std::start_cheat_transaction_version_global;
use starknet::SyscallResultTrait;
use crate::interfaces::{MetaTransactionV0ABIDispatcher, MetaTransactionV0ABIDispatcherTrait};

//
// Setup
//

fn setup_dispatchers() -> (IGetInfoDispatcher, MetaTransactionV0ABIDispatcher) {
    let contract_address = utils::declare_and_deploy("GetInfoMock", array![]);
    let get_info_dispatcher = IGetInfoDispatcher { contract_address };

    let contract_address = utils::declare_and_deploy("MetaTransactionV0", array![]);
    let meta_tx_dispatcher = MetaTransactionV0ABIDispatcher { contract_address };

    (get_info_dispatcher, meta_tx_dispatcher)
}

//
// Tests
//

#[test]
fn test_meta_tx_v0_context_update() {
    let (get_info_dispatcher, meta_tx_dispatcher) = setup_dispatchers();

    // Setup custom tx info
    let current_tx_info = setup_custom_tx_info();

    // Get tx info
    let tx_info = get_info_dispatcher.get_info();

    // Assert initial state of tx info
    assert_eq!(tx_info.version, current_tx_info.version);

    // Execute meta tx
    let mut result = meta_tx_dispatcher
        .execute_meta_tx_v0(
            get_info_dispatcher.contract_address,
            selector!("get_info"),
            array![].span(),
            current_tx_info.signature,
        )
        .unwrap_syscall();
    let result_tx_info = Serde::<starknet::TxInfo>::deserialize(ref result).unwrap();

    // Assert tx info
    assert_eq!(result_tx_info.version, 0);
}

//
// Helpers
//

fn setup_custom_tx_info() -> starknet::TxInfo {
    start_cheat_transaction_version_global(3);
    starknet::get_execution_info().unbox().tx_info.unbox()
}
