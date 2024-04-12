// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.11.0 (token/utils/cryptography/merkle.cairo)

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
            self: @ComponentState<TContractState>, proof: Span<felt252>, leaf: felt252
        ) -> felt252 {
            let length = proof.len();
            let mut computedHash = leaf;
            let mut counter = 0;

            loop {
                if counter == length {
                    break ();
                }
                computedHash = InternalTrait::hash_pair(self, computedHash, *proof.at(counter));
                counter += 1;
            };
            return computedHash;
        }

        fn hash_pair(self: @ComponentState<TContractState>, a: felt252, b: felt252) -> felt252 {
            let mut state = PoseidonTrait::new();
            state = state.update_with(a);
            state = state.update_with(b);
            state.finalize()
        }
    }
}
