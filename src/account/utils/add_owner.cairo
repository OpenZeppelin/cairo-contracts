
mod AddOwner {
    use hash::{HashStateTrait, HashStateExTrait};
    use pedersen::PedersenTrait;
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use starknet::get_tx_info;

    #[derive(Copy, Drop, Hash)]
    struct StarkNetDomain {
        name: felt252,
        version: felt252,
        chain_id: felt252
    }

    #[derive(Copy, Drop, Serde)]
    struct AddOwner {
        account: ContractAddress,
        owner: felt252
    }

    fn build_hash(new_owner: felt252) -> felt252 {
        let domain = StarkNetDomain {
            name: 'Account.add_owner', version: 1, chain_id: get_tx_info().unbox().chain_id,
        };

        PedersenTrait::new(0)
            .update('StarkNet Message')
            .update(hash_domain(@domain))
            .update(get_contract_address().into())
            .update(hash_add_owner_message(new_owner))
            .update(4)
            .finalize()
    }

    fn hash_domain(domain: @StarkNetDomain) -> felt252 {
        PedersenTrait::new(0)
            .update(selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)"))
            .update_with(*domain)
            .update(4)
            .finalize()
    }

    fn hash_add_owner_message(new_owner: felt252) -> felt252 {
        PedersenTrait::new(0)
            .update(selector!("AddOwner(account:felt,owner:felt)"))
            .update(get_contract_address().into())
            .update(new_owner)
            .update(3)
            .finalize()
    }
}
