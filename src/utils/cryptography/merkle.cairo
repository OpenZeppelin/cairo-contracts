// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.11.0 (token/utils/cryptography/merkle.cairo)

/// # Merkle Proof Verifier Component
///
/// Merkle Proof Verifier Component enables contracts to verify merkle proofs.
#[starknet::interface]
trait IMerkle<TContractState> {
    fn verify(self: @TContractState, proof: Span<felt252>, root: felt252, leaf: felt252) -> bool;
}

#[starknet::component]
mod MerkleComponent {
    use core::hash::HashStateExTrait;
    use hash::{HashStateTrait, Hash};
    use poseidon::PoseidonTrait;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {}

    #[embeddable_as(MerkleImpl)]
    impl Merkle<
        TContractState, +HasComponent<TContractState>
    > of super::IMerkle<ComponentState<TContractState>> {
        fn verify(
            self: @ComponentState<TContractState>,
            proof: Span<felt252>,
            root: felt252,
            leaf: felt252
        ) -> bool {
            return InternalTrait::process_proof(self, proof, leaf) == root;
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn process_proof(
            self: @ComponentState<TContractState>, mut proof: Span<felt252>, mut leaf: felt252
        ) -> felt252 {
             while let Option::Some(element) = proof
            .pop_front() {
                leaf =
                    if Into::<felt252, u256>::into(leaf) < (*element).into() {
                        InternalTrait::hash_pair(self, leaf, *element)
                    } else {
                        InternalTrait::hash_pair(self, *element, leaf)
                    };
            };
        leaf
        }

        fn hash_pair(self: @ComponentState<TContractState>, a: felt252, b: felt252) -> felt252 {
            let mut state = PoseidonTrait::new();
            state = state.update_with(a);
            state = state.update_with(b);
            state.finalize()
        }
    }
}
