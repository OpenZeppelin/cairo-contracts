use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::poseidon_hash_span;
use openzeppelin_utils::cryptography::hashes::PoseidonCHasher;
use openzeppelin_utils::cryptography::merkle_proof::{
    process_proof, process_multi_proof, verify, verify_multi_proof, verify_poseidon
};
use starknet::{ContractAddress, contract_address_const};

#[derive(Serde, Copy, Drop, Hash)]
struct Leaf {
    address: ContractAddress,
    amount: u128,
}

fn LEAVES() -> Span<Leaf> {
    [
        Leaf {
            address: contract_address_const::<
                0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc8
            >(),
            amount: 0xfc104e31d098d1ab488fc1acaeb0269
        },
        Leaf {
            address: contract_address_const::<
                0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffc66ca5c000
            >(),
            amount: 0xfc104e31d098d1ab488fc1acaeb0269
        },
        Leaf {
            address: contract_address_const::<
                0x6a1f098854799debccf2d3c4059ff0f02dbfef6673dc1fcbfffffffffffffc8
            >(),
            amount: 0xfc104e31d098d1ab488fc1acaeb0269
        },
        Leaf {
            address: contract_address_const::<
                0xfa6541b7909bfb5e8585f1222fcf272eea352c7e0e8ed38c988bd1e2a85e82
            >(),
            amount: 0xaa8565d732c2c9fa5f6c001d89d5c219
        },
    ].span()
}

//
// verify
//

#[test]
fn test_valid_merkle_proof() {
    let leaves = LEAVES();
    let hash = leaf_hash(*leaves.at(0));
    // `root` and `proof` were computed using @ericnordelo/strk-merkle-tree
    let root = 0x02fde31926e7ef7ac8c0ff1d438e4a177a4cf1a79960381806e3d546071bbc47;
    let proof = [
        0x0610491af77d9d95e10b0f9183a1d94c7472eda1ea081384ff48e6b8dbda73d3,
        0x82d19fa40550cddbb066d587210180c68fcbaa221176e885b5519274580c25
    ].span();

    assert_eq!(process_proof::<PoseidonCHasher>(proof, hash), root);
    assert!(verify::<PoseidonCHasher>(proof, root, hash));
    assert!(verify_poseidon(proof, root, hash));

    // For demonstration, it is also possible to create valid
    // proofs for certain values *NOT* in elements:
    let no_such_leaf = poseidon_hash_span([hash, *proof.at(0)].span());
    let second_proof = [0x82d19fa40550cddbb066d587210180c68fcbaa221176e885b5519274580c25].span();

    assert_eq!(process_proof::<PoseidonCHasher>(second_proof, no_such_leaf), root);
    assert!(verify::<PoseidonCHasher>(second_proof, root, no_such_leaf));
    assert!(verify_poseidon(second_proof, root, no_such_leaf));
}

#[test]
fn test_invalid_merkle_proof() {
    let leaves = LEAVES();
    let hash = leaf_hash(*leaves.at(0));
    // `root` was computed using @ericnordelo/strk-merkle-tree
    let root = 0x02fde31926e7ef7ac8c0ff1d438e4a177a4cf1a79960381806e3d546071bbc47;
    let invalid_proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c, 'invalid'
    ].span();

    assert!(process_proof::<PoseidonCHasher>(invalid_proof, hash) != root);
    assert!(!verify::<PoseidonCHasher>(invalid_proof, root, hash));
    assert!(!verify_poseidon(invalid_proof, root, hash));
}

//
// multi_proof_verify
//

#[test]
fn test_valid_merkle_multi_proof() {
    let leaves = LEAVES();
    let leaves_to_prove = [leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1))].span();
    // `root`, `proof`, and `proof_flags` were computed using @ericnordelo/strk-merkle-tree
    let root = 0x02fde31926e7ef7ac8c0ff1d438e4a177a4cf1a79960381806e3d546071bbc47;
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();
    let proof_flags = [false, false, true].span();

    assert_eq!(process_multi_proof::<PoseidonCHasher>(proof, proof_flags, leaves_to_prove), root);
    assert!(verify_multi_proof::<PoseidonCHasher>(proof, proof_flags, root, leaves_to_prove));
}

#[test]
fn test_invalid_merkle_multi_proof() {
    let leaves = LEAVES();
    let leaves_to_prove = [leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1))].span();
    // `root` and `proof_flags` were computed using @ericnordelo/strk-merkle-tree
    let root = 0x02fde31926e7ef7ac8c0ff1d438e4a177a4cf1a79960381806e3d546071bbc47;
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c, 'invalid'
    ].span();
    let proof_flags = [false, false, true].span();

    assert!(process_multi_proof::<PoseidonCHasher>(proof, proof_flags, leaves_to_prove) != root);
    assert!(!verify_multi_proof::<PoseidonCHasher>(proof, proof_flags, root, leaves_to_prove));
}

#[test]
fn test_invalid_merkle_multi_proof_flags() {
    let leaves = LEAVES();
    let leaves_to_prove = [leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1))].span();
    // `root` and `proof` were computed using @ericnordelo/strk-merkle-tree
    let root = 0x02fde31926e7ef7ac8c0ff1d438e4a177a4cf1a79960381806e3d546071bbc47;
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();
    let proof_flags = [false, true, false].span();

    assert!(process_multi_proof::<PoseidonCHasher>(proof, proof_flags, leaves_to_prove) != root);
    assert!(!verify_multi_proof::<PoseidonCHasher>(proof, proof_flags, root, leaves_to_prove));
}

#[test]
#[should_panic(expected: ("MerkleProof: invalid multi proof",))]
fn test_process_multi_proof_invalid_len_proof_flags_panics() {
    let leaves = LEAVES();
    let leaves_to_prove = [leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1))].span();
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();

    // `proof_flags.len()` is not equal to `proof.len() + leaves_to_prove.len() + 1`
    let proof_flags = [true, false].span();

    process_multi_proof::<PoseidonCHasher>(proof, proof_flags, leaves_to_prove);
}

#[test]
#[should_panic(expected: ("MerkleProof: invalid multi proof",))]
fn test_verify_multi_proof_invalid_len_proof_flags_panics() {
    let leaves = LEAVES();
    let leaves_to_prove = [leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1))].span();
    let root = 0x02fde31926e7ef7ac8c0ff1d438e4a177a4cf1a79960381806e3d546071bbc47;
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();

    // `proof_flags.len()` is not equal to `proof.len() + leaves_to_prove.len() + 1`
    let proof_flags = [true, false].span();

    verify_multi_proof::<PoseidonCHasher>(proof, proof_flags, root, leaves_to_prove);
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_process_multi_proof_flags_extra_leaves_expected() {
    let leaves = LEAVES();
    let leaves_to_prove = [
        leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1)), leaf_hash(*leaves.at(2))
    ].span();
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();

    // For each true one leaf is expected
    let proof_flags = [true, true, true, true].span();

    process_multi_proof::<PoseidonCHasher>(proof, proof_flags, leaves_to_prove);
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_process_multi_proof_flags_extra_proofs_expected() {
    let leaves = LEAVES();
    let leaves_to_prove = [
        leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1)), leaf_hash(*leaves.at(2))
    ].span();
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();

    // For each false one leaf is expected
    let proof_flags = [true, false, false, false].span();

    process_multi_proof::<PoseidonCHasher>(proof, proof_flags, leaves_to_prove);
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_verify_multi_proof_flags_extra_leaves_expected() {
    let leaves = LEAVES();
    let leaves_to_prove = [
        leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1)), leaf_hash(*leaves.at(2))
    ].span();
    let root = 0x02fde31926e7ef7ac8c0ff1d438e4a177a4cf1a79960381806e3d546071bbc47;
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();

    // For each true one leaf is expected
    let proof_flags = [true, true, true, true].span();

    verify_multi_proof::<PoseidonCHasher>(proof, proof_flags, root, leaves_to_prove);
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_verify_multi_proof_flags_extra_proofs_expected() {
    let leaves = LEAVES();
    let leaves_to_prove = [
        leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1)), leaf_hash(*leaves.at(2))
    ].span();
    let root = 0x02fde31926e7ef7ac8c0ff1d438e4a177a4cf1a79960381806e3d546071bbc47;
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();

    // For each false one leaf is expected
    let proof_flags = [true, false, false, false].span();

    verify_multi_proof::<PoseidonCHasher>(proof, proof_flags, root, leaves_to_prove);
}

//
// Helpers
//

fn leaf_hash(leaf: Leaf) -> felt252 {
    poseidon_hash_span([0, poseidon_hash_span([leaf.address.into(), leaf.amount.into()].span())].span())
}
