#[starknet::contract]
mod Ownable {
    use openzeppelin::access::ownable::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        _owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred
    }
    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self._owner.read()
        }

        fn assert_only_owner(self: @ContractState) {
            let owner: ContractAddress = self.owner();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), 'Caller is the zero address');
            assert(caller == owner, 'Caller is not the owner');
        }

        fn _transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let previous_owner: ContractAddress = self.owner();
            self._owner.write(new_owner);
            self
                .emit(
                    Event::OwnershipTransferred(
                        OwnershipTransferred {
                            previous_owner: previous_owner, new_owner: new_owner
                        }
                    )
                );
        }
    }

    #[external(v0)]
    impl OwnableImpl of interface::IOwnable<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            self.owner()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert(!new_owner.is_zero(), 'New owner is the zero address');
            self.assert_only_owner();
            self._transfer_ownership(new_owner);
        }

        fn renounce_ownership(ref self: ContractState) {
            self.assert_only_owner();
            self._transfer_ownership(Zeroable::zero());
        }
    }

    #[external(v0)]
    impl OwnableCamelOnlyImpl of interface::IOwnableCamelOnly<ContractState> {
        fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
            //let mut unsafe_state = OwnableImpl::unsafe_new_contract_state();
            OwnableImpl::transfer_ownership(ref self, newOwner);
        }

        fn renounceOwnership(ref self: ContractState) {
            //let mut unsafe_state = Ownable::unsafe_new_contract_state();
            OwnableImpl::renounce_ownership(ref self);
        }
    }
}
