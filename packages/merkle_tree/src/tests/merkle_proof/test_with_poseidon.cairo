use core::poseidon::poseidon_hash_span;
use openzeppelin_merkle_tree::hashes::PoseidonCHasher;
use openzeppelin_merkle_tree::merkle_proof::{
    process_proof, process_multi_proof, verify, verify_multi_proof, verify_poseidon
};
use starknet::{ContractAddress, contract_address_const};
use super::common::{Leaf, LEAVES};

//
// verify
//

#[test]
fn test_valid_merkle_proof() {
    let leaves = LEAVES();
    let hash = leaf_hash(*leaves.at(0));
    // `root` and `proof` were computed using @ericnordelo/strk-merkle-tree
    let root = 0x013f43fdca44b32f5334414b385b46aa1016d0172a1f066eab4cc93636426fcc;
    let proof = [
        0x05b151ebb9201ce27c56a70f5d0571ccfb9d9d62f12b8ccab7801ba87ec21a2f,
        0x2b7d689bd2ff488fd06dfb8eb22f5cdaba1e5d9698d3fabff2f1801852dbb2
    ].span();

    assert_eq!(process_proof::<PoseidonCHasher>(proof, hash), root);
    assert!(verify::<PoseidonCHasher>(proof, root, hash));
    assert!(verify_poseidon(proof, root, hash));

    // For demonstration, it is also possible to create valid
    // proofs for certain values *NOT* in elements:
    let no_such_leaf = PoseidonCHasher::commutative_hash(hash, *proof.at(0));
    let second_proof = [0x2b7d689bd2ff488fd06dfb8eb22f5cdaba1e5d9698d3fabff2f1801852dbb2].span();

    assert_eq!(process_proof::<PoseidonCHasher>(second_proof, no_such_leaf), root);
    assert!(verify::<PoseidonCHasher>(second_proof, root, no_such_leaf));
    assert!(verify_poseidon(second_proof, root, no_such_leaf));
}

#[test]
fn test_invalid_merkle_proof() {
    let leaves = LEAVES();
    let hash = leaf_hash(*leaves.at(0));
    // `root` was computed using @ericnordelo/strk-merkle-tree
    let root = 0x013f43fdca44b32f5334414b385b46aa1016d0172a1f066eab4cc93636426fcc;
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
    let root = 0x013f43fdca44b32f5334414b385b46aa1016d0172a1f066eab4cc93636426fcc;
    let proof = [0x2b7d689bd2ff488fd06dfb8eb22f5cdaba1e5d9698d3fabff2f1801852dbb2].span();
    let proof_flags = [true, false].span();

    assert_eq!(process_multi_proof::<PoseidonCHasher>(proof, proof_flags, leaves_to_prove), root);
    assert!(verify_multi_proof::<PoseidonCHasher>(proof, proof_flags, root, leaves_to_prove));
}

#[test]
fn test_invalid_merkle_multi_proof() {
    let leaves = LEAVES();
    let leaves_to_prove = [leaf_hash(*leaves.at(0)), leaf_hash(*leaves.at(1))].span();
    // `root` and `proof_flags` were computed using @ericnordelo/strk-merkle-tree
    let root = 0x013f43fdca44b32f5334414b385b46aa1016d0172a1f066eab4cc93636426fcc;
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
    let root = 0x013f43fdca44b32f5334414b385b46aa1016d0172a1f066eab4cc93636426fcc;
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
    let root = 0x013f43fdca44b32f5334414b385b46aa1016d0172a1f066eab4cc93636426fcc;
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

    // For each false one proof is expected
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
    let root = 0x013f43fdca44b32f5334414b385b46aa1016d0172a1f066eab4cc93636426fcc;
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
    let root = 0x013f43fdca44b32f5334414b385b46aa1016d0172a1f066eab4cc93636426fcc;
    let proof = [
        0x044fdc540a81d0189ed30b49d64136f9e8bd499c942ba170404ef0b9406e524c,
        0x05fb6a626bb2c1e12fc2d6fa7f218ec06928ba5febf4d5677c2c5060827e383b
    ].span();

    // For each false one proof is expected
    let proof_flags = [true, false, false, false].span();

    verify_multi_proof::<PoseidonCHasher>(proof, proof_flags, root, leaves_to_prove);
}

//
// Helpers
//

fn leaf_hash(leaf: Leaf) -> felt252 {
    poseidon_hash_span(
        [poseidon_hash_span([leaf.address.into(), leaf.amount.into()].span())].span()
    )
}
