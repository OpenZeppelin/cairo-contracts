use openzeppelin::tests::mocks::account_mocks::SnakeAccountMock;
use openzeppelin::tests::mocks::erc1155_receiver_mocks::{
    CamelERC1155ReceiverMock, SnakeERC1155ReceiverMock
};
use openzeppelin::tests::mocks::src5_mocks::SRC5Mock;
use openzeppelin::tests::utils::constants::{
    PUBKEY, TOKEN_ID, TOKEN_ID_2, TOKEN_VALUE, TOKEN_VALUE_2
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::ERC1155Component::{TransferBatch, ApprovalForAll, TransferSingle};
use openzeppelin::token::erc1155::ERC1155Component;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;


pub(crate) fn setup_receiver() -> ContractAddress {
    utils::deploy(SnakeERC1155ReceiverMock::TEST_CLASS_HASH, array![])
}

pub(crate) fn setup_camel_receiver() -> ContractAddress {
    utils::deploy(CamelERC1155ReceiverMock::TEST_CLASS_HASH, array![])
}

pub(crate) fn setup_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(SnakeAccountMock::TEST_CLASS_HASH, calldata)
}

pub(crate) fn setup_account_with_salt(salt: felt252) -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy_with_salt(SnakeAccountMock::TEST_CLASS_HASH, calldata, salt)
}

pub(crate) fn setup_src5() -> ContractAddress {
    utils::deploy(SRC5Mock::TEST_CLASS_HASH, array![])
}

pub(crate) fn assert_event_approval_for_all(
    contract: ContractAddress, owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    let event = utils::pop_log::<ERC1155Component::Event>(contract).unwrap();
    let expected = ERC1155Component::Event::ApprovalForAll(
        ApprovalForAll { owner, operator, approved }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("ApprovalForAll"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(operator);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_event_transfer_single(
    contract: ContractAddress,
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_id: u256,
    value: u256
) {
    let event = utils::pop_log::<ERC1155Component::Event>(contract).unwrap();
    let id = token_id;
    let expected = ERC1155Component::Event::TransferSingle(
        TransferSingle { operator, from, to, id, value }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("TransferSingle"));
    indexed_keys.append_serde(operator);
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_event_transfer_batch(
    contract: ContractAddress,
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_ids: Span<u256>,
    values: Span<u256>
) {
    let event = utils::pop_log::<ERC1155Component::Event>(contract).unwrap();
    let ids = token_ids;
    let expected = ERC1155Component::Event::TransferBatch(
        TransferBatch { operator, from, to, ids, values }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("TransferBatch"));
    indexed_keys.append_serde(operator);
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

pub(crate) fn assert_only_event_transfer_single(
    contract: ContractAddress,
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_id: u256,
    value: u256
) {
    assert_event_transfer_single(contract, operator, from, to, token_id, value);
    utils::assert_no_events_left(contract);
}

pub(crate) fn assert_only_event_transfer_batch(
    contract: ContractAddress,
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    token_ids: Span<u256>,
    values: Span<u256>
) {
    assert_event_transfer_batch(contract, operator, from, to, token_ids, values);
    utils::assert_no_events_left(contract);
}

pub(crate) fn assert_only_event_approval_for_all(
    contract: ContractAddress, owner: ContractAddress, operator: ContractAddress, approved: bool
) {
    assert_event_approval_for_all(contract, owner, operator, approved);
    utils::assert_no_events_left(contract);
}

pub(crate) fn get_ids_and_values() -> (Span<u256>, Span<u256>) {
    let ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, TOKEN_VALUE_2].span();
    (ids, values)
}

pub(crate) fn get_ids_and_split_values(split: u256) -> (Span<u256>, Span<u256>) {
    let ids = array![TOKEN_ID, TOKEN_ID].span();
    let values = array![TOKEN_VALUE - split, split].span();
    (ids, values)
}
