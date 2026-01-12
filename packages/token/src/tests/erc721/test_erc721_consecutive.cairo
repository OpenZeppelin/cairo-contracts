use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{BASE_URI, NAME, RECIPIENT, SYMBOL};
use openzeppelin_utils::serde::SerializedAppend;

#[test]
fn test_deploys_consecutive_mock() {
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(RECIPIENT);
    calldata.append_serde(1_u64);

    let contract_address = utils::declare_and_deploy("ERC721ConsecutiveMock", calldata);
    assert(contract_address.is_non_zero(), 'deploy failed');
}
