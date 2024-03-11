use openzeppelin::tests::mocks::snip12_mocks::SNIP12Mock::SNIP12MetadataImpl;
use openzeppelin::tests::mocks::snip12_mocks::{MESSAGE_TYPE_HASH, Message};
use openzeppelin::tests::utils::constants::{OWNER, RECIPIENT};
use openzeppelin::utils::cryptography::snip12::{
    STARKNET_DOMAIN_TYPE_HASH, StarknetDomain, StructHash, OffchainMessageHash,
    OffchainMessageHashImpl
};
use poseidon::poseidon_hash_span;

#[test]
fn test_starknet_domain_type_hash() {
    let expected = selector!(
        "\"StarknetDomain\"(\"name\":\"shortstring\",\"version\":\"shortstring\",\"chainId\":\"shortstring\",\"revision\":\"shortstring\")"
    );
    assert_eq!(STARKNET_DOMAIN_TYPE_HASH, expected);
}

#[test]
fn test_StructHashStarknetDomainImpl() {
    let domain = StarknetDomain { name: 'DAPP_NAME', version: 'v1', chain_id: 'TEST', revision: 1 };

    let expected = poseidon_hash_span(
        array![
            STARKNET_DOMAIN_TYPE_HASH, domain.name, domain.version, domain.chain_id, domain.revision
        ]
            .span()
    );
    assert_eq!(domain.hash_struct(), expected);
}

#[test]
fn test_OffchainMessageHashImpl() {
    let message = Message { recipient: RECIPIENT(), amount: 100, nonce: 1, expiry: 1000 };
    let domain = StarknetDomain {
        name: 'SNIP12Mock', version: 'v1', chain_id: 'TEST', revision: 1
    };

    starknet::testing::set_chain_id('TEST');

    let expected = poseidon_hash_span(
        array!['StarkNet Message', domain.hash_struct(), OWNER().into(), message.hash_struct()]
            .span()
    );
    assert_eq!(message.get_message_hash(OWNER()), expected);
}

