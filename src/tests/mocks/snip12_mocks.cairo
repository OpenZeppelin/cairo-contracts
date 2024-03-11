use core::hash::HashStateExTrait;
use hash::{HashStateTrait, Hash};
use openzeppelin::utils::snip12::{SNIP12Metadata, StructHash, OffchainMessageHashImpl};
use poseidon::PoseidonTrait;
use starknet::ContractAddress;

const MESSAGE_TYPE_HASH: felt252 =
    0x120ae1bdaf7c1e48349da94bb8dad27351ca115d6605ce345aee02d68d99ec1;

#[derive(Copy, Drop, Hash)]
struct Message {
    recipient: ContractAddress,
    amount: u256,
    nonce: felt252,
    expiry: u64
}

impl StructHashImpl of StructHash<Message> {
    fn hash_struct(self: @Message) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(MESSAGE_TYPE_HASH).update_with(*self).finalize()
    }
}

#[starknet::contract]
mod SNIP12Mock {
    use openzeppelin::account::dual_account::{DualCaseAccount, DualCaseAccountABI};
    use openzeppelin::utils::cryptography::nonces::NoncesComponent;
    use starknet::ContractAddress;
    use super::{Message, OffchainMessageHashImpl, SNIP12Metadata};

    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;
    impl InternalImpl = NoncesComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        nonces: NoncesComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        NoncesEvent: NoncesComponent::Event
    }

    /// Required for hash computation.
    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'SNIP12Mock'
        }
        fn version() -> felt252 {
            'v1'
        }
    }

    #[external(v0)]
    fn is_valid_signature_for_transfer(
        ref self: ContractState,
        owner: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        nonce: felt252,
        expiry: u64,
        signature: Array<felt252>
    ) -> bool {
        assert(starknet::get_block_timestamp() <= expiry, 'Expired signature');

        // Check and increase nonce.
        self.nonces.use_checked_nonce(owner, nonce);

        // Build hash for calling `is_valid_signature`.
        let message = Message { recipient, amount, nonce, expiry };
        let hash = message.get_message_hash(starknet::get_caller_address());

        let is_valid_signature_felt = DualCaseAccount { contract_address: owner }
            .is_valid_signature(hash, signature);

        // Check either 'VALID' or True for backwards compatibility.
        let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
            || is_valid_signature_felt == 1;

        is_valid_signature
    }
}
