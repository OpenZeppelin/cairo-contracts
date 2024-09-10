use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use openzeppelin_testing::constants;
use openzeppelin_testing::signing::{StarkKeyPair, StarkSerializedSigning};
use openzeppelin_testing as utils;
use openzeppelin_token::erc20::ERC20Component::{ERC20MixinImpl, InternalImpl};
use openzeppelin_token::erc20::extensions::ERC20PermitComponent::{
    ERC20PermitImpl, SNIP12MetadataExternalImpl
};
use openzeppelin_token::erc20::extensions::erc20_permit::interface::{ERC20PermitABIDispatcher, ERC20PermitABIDispatcherTrait};
use openzeppelin_token::erc20::extensions::erc20_permit::erc20_permit::Permit;
use openzeppelin_utils::cryptography::snip12::{
    StarknetDomain, StructHashStarknetDomainImpl
};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::signature::stark_curve::StarkCurveSignerImpl;
use snforge_std::{start_cheat_caller_address, start_cheat_block_timestamp, start_cheat_chain_id_global};
use starknet::ContractAddress;

//
// Test Data
//

#[derive(Copy, Drop)]
struct TestData {
    contract_address: ContractAddress,
    owner: ContractAddress,
    key_pair: StarkKeyPair,
    spender: ContractAddress,
    amount: u256,
    deadline: u64,
    token_supply: u256,
    name: @ByteArray,
    symbol: @ByteArray,
    metadata_name: felt252,
    metadata_version: felt252,
    chain_id: felt252,
    revision: felt252
}

fn TEST_DATA() -> TestData {
    TestData {
        contract_address: constants::CONTRACT_ADDRESS(),
        owner: constants::OWNER(),
        key_pair: constants::stark::KEY_PAIR(),
        spender: constants::SPENDER(),
        amount: constants::TOKEN_VALUE,
        deadline: constants::TIMESTAMP,
        token_supply: constants::SUPPLY,
        name: @constants::NAME(),
        symbol: @constants::SYMBOL(),
        metadata_name: 'My unique token name', // As in ERC20Permit preset
        metadata_version: 'v1', // As in ERC20Permit preset
        chain_id: constants::CHAIN_ID,
        revision: 1 // As in the current SNIP-12 implementation
    }
}

//
// Setup
//

fn setup(data: TestData) -> ERC20PermitABIDispatcher {
    start_cheat_chain_id_global(data.chain_id);

    utils::declare_and_deploy_at("DualCaseAccountMock", data.owner, array![data.key_pair.public_key]);

    let mut calldata = array![];
    calldata.append_serde(data.name.clone());
    calldata.append_serde(data.symbol.clone());
    calldata.append_serde(data.token_supply);
    calldata.append_serde(data.owner);
    utils::declare_and_deploy_at("ERC20Permit", data.contract_address, calldata);

    ERC20PermitABIDispatcher { contract_address: data.contract_address }
}

//
// IERC20Permit
//

#[test]
fn test_valid_permit_default_data() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    assert_valid_allowance(owner, spender, 0);

    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);

    assert_valid_allowance(owner, spender, amount);
    assert_valid_nonce(owner, nonce + 1);
}

#[test]
fn test_valid_permit_other_data() {
    let mut data = TEST_DATA();
    data.spender = constants::OTHER();
    data.amount = constants::TOKEN_VALUE_2;
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    assert_valid_allowance(owner, spender, 0);

    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);

    assert_valid_allowance(owner, spender, amount);
    assert_valid_nonce(owner, nonce + 1);
}

#[test]
fn test_spend_permit() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(data, nonce);
    start_cheat_caller_address(dispatcher.contract_address, spender);

    dispatcher.permit(owner, spender, amount, deadline, signature);
    dispatcher.transfer_from(owner, spender, amount);

    assert_valid_balance(spender, amount);
    assert_valid_balance(owner, data.token_supply - amount);
    assert_valid_allowance(owner, spender, 0);
    assert_valid_nonce(owner, nonce + 1);
}

#[test]
fn test_spend_half_permit() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(data, nonce);
    start_cheat_caller_address(dispatcher.contract_address, spender);

    dispatcher.permit(owner, spender, amount, deadline, signature);
    let transfer_amount = amount / 2;
    dispatcher.transfer_from(owner, spender, transfer_amount);

    assert_valid_balance(spender, transfer_amount);
    assert_valid_balance(owner, data.token_supply - transfer_amount);
    assert_valid_allowance(owner, spender, amount - transfer_amount);
    assert_valid_nonce(owner, nonce + 1);
}

#[test]
fn test_subsequent_permits() {
    let mut data = TEST_DATA();
    let (owner, spender, amount_1, deadline) = (
        data.owner, data.spender, data.amount, data.deadline
    );
    let dispatcher = setup(data);

    let mut expected_owner_balance = data.token_supply;
    let mut expected_spender_balance = 0;
    start_cheat_caller_address(dispatcher.contract_address, spender);

    // Permit 1
    let nonce_1 = dispatcher.nonces(owner);
    let signature_1 = prepare_permit_signature(data, nonce_1);

    dispatcher.permit(owner, spender, amount_1, deadline, signature_1);
    dispatcher.transfer_from(owner, spender, amount_1);

    expected_owner_balance -= amount_1;
    expected_spender_balance += amount_1;
    assert_valid_balance(owner, expected_owner_balance);
    assert_valid_balance(spender, expected_spender_balance);
    assert_valid_allowance(owner, spender, 0);
    assert_valid_nonce(owner, nonce_1 + 1);

    // Permit 2
    data.amount = constants::TOKEN_VALUE_2;
    let amount_2 = data.amount;
    let nonce_2 = dispatcher.nonces(owner);
    let signature_2 = prepare_permit_signature(data, nonce_2);

    dispatcher.permit(owner, spender, amount_2, deadline, signature_2);
    dispatcher.transfer_from(owner, spender, amount_2);

    expected_owner_balance -= amount_2;
    expected_spender_balance += amount_2;
    assert_valid_balance(owner, expected_owner_balance);
    assert_valid_balance(spender, expected_spender_balance);
    assert_valid_allowance(owner, spender, 0);
    assert_valid_nonce(owner, nonce_2 + 1);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_replay_attack() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let nonce = dispatcher.nonces(owner);
    start_cheat_caller_address(dispatcher.contract_address, spender);

    // 1st call is fine
    let signature = prepare_permit_signature(data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);

    // 2nd call must fail (nonce already used)
    let signature = prepare_permit_signature(data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
fn test_domain_separator() {
    let data = TEST_DATA();
    let dispatcher = setup(data);

    let sn_domain = StarknetDomain {
        name: data.metadata_name,
        version: data.metadata_version,
        chain_id: data.chain_id,
        revision: data.revision
    };
    let expected_domain_separator = sn_domain.hash_struct();
    assert_eq!(dispatcher.DOMAIN_SEPARATOR(), expected_domain_separator);
}

//
// SNIP12Metadata
//

#[test]
fn test_snip12_metadata() {
    let data = TEST_DATA();
    let dispatcher = setup(data);

    let (metadata_name, metadata_version) = dispatcher.snip12_metadata();
    assert_eq!(metadata_name, data.metadata_name, "Invalid metadata name");
    assert_eq!(metadata_version, data.metadata_version, "Invalid metadata version");
}

//
// Invalid signature
//

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_owner() {
    let data = TEST_DATA();
    let (spender, amount, deadline) = (data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let another_account = constants::OTHER();
    utils::deploy_another_at(data.owner, another_account, array![data.key_pair.public_key]);
    let nonce = dispatcher.nonces(another_account);
    let signature = prepare_permit_signature(data, nonce);
    dispatcher.permit(another_account, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_token_address() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);

    let mut modified_data = data;
    modified_data.contract_address = constants::OTHER();
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(modified_data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_spender() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let mut modified_data = data;
    modified_data.spender = constants::OTHER();
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(modified_data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_amount() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let mut modified_data = data;
    modified_data.amount = constants::TOKEN_VALUE_2;
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(modified_data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_nonce() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let another_nonce = dispatcher.nonces(owner) + 1;
    let signature = prepare_permit_signature(data, another_nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_sig_r() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(data, nonce);
    let (sig_r, sig_s) = (*signature.at(0), *signature.at(1));
    let modified_signature = array![sig_r + 1, sig_s];
    dispatcher.permit(owner, spender, amount, deadline, modified_signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_sig_s() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(data, nonce);
    let (sig_r, sig_s) = (*signature.at(0), *signature.at(1));
    let modified_signature = array![sig_r, sig_s + 1];
    dispatcher.permit(owner, spender, amount, deadline, modified_signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_metadata_name() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let mut modified_data = data;
    modified_data.metadata_name = 'ANOTHER_NAME';
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(modified_data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_metadata_version() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let mut modified_data = data;
    modified_data.metadata_version = 'ANOTHER_VERSION';
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(modified_data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_signing_key() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let mut modified_data = data;
    modified_data.key_pair = constants::stark::KEY_PAIR_2();
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(modified_data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_chain_id() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let mut modified_data = data;
    modified_data.chain_id = 'ANOTHER_CHAIN_ID';
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(modified_data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

#[test]
#[should_panic(expected: ('ERC20Permit: invalid signature',))]
fn test_invalid_sig_bad_revision() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let mut modified_data = data;
    modified_data.revision = 'ANOTHER_REVISION';
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(modified_data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

//
// Expired signature
//

#[test]
#[should_panic(expected: ('ERC20Permit: expired signature',))]
fn test_invalid_sig_bad_deadline() {
    let data = TEST_DATA();
    let (owner, spender, amount, deadline) = (data.owner, data.spender, data.amount, data.deadline);
    let dispatcher = setup(data);

    let timestamp_after_deadline = deadline + 1;
    start_cheat_block_timestamp(dispatcher.contract_address, timestamp_after_deadline);
    let nonce = dispatcher.nonces(owner);
    let signature = prepare_permit_signature(data, nonce);
    dispatcher.permit(owner, spender, amount, deadline, signature);
}

//
// Helpers
//

fn prepare_permit_signature(
    data: TestData, nonce: felt252
) -> Array<felt252> {
    let sn_domain = StarknetDomain {
        name: data.metadata_name,
        version: data.metadata_version,
        chain_id: data.chain_id,
        revision: data.revision
    };
    let permit = Permit {
        token: data.contract_address, spender: data.spender, amount: data.amount, nonce, deadline: data.deadline
    };
    let msg_hash = PoseidonTrait::new()
        .update_with('StarkNet Message')
        .update_with(sn_domain.hash_struct())
        .update_with(data.owner)
        .update_with(permit.hash_struct())
        .finalize();

    data.key_pair.serialized_sign(msg_hash)
}

fn assert_valid_nonce(account: ContractAddress, expected: felt252) {
    let dispatcher = ERC20PermitABIDispatcher { contract_address: constants::CONTRACT_ADDRESS() };
    assert_eq!(dispatcher.nonces(account), expected);
}

fn assert_valid_allowance(
    owner: ContractAddress, spender: ContractAddress, expected: u256
) {
    let dispatcher = ERC20PermitABIDispatcher { contract_address: constants::CONTRACT_ADDRESS() };
    assert_eq!(dispatcher.allowance(owner, spender), expected);
}

fn assert_valid_balance(account: ContractAddress, expected: u256) {
    let dispatcher = ERC20PermitABIDispatcher { contract_address: constants::CONTRACT_ADDRESS() };
    assert_eq!(dispatcher.balance_of(account), expected);
}
