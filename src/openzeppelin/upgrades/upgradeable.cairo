use starknet::class_hash::ClassHash;

#[abi]
trait IUpgradeable {
    fn upgrade(impl_hash: ClassHash);
    fn upgrade_and_call(impl_hash: ClassHash, selector: felt252, calldata: Array<felt252>);
}

#[contract]
mod Upgradeable {
    use super::IUpgradeable;
    use array::ArrayTrait;
    use starknet::class_hash::ClassHash;
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use zeroable::Zeroable;

    #[event]
    fn Upgraded(implementation: ClassHash) {}

    impl UpgradeableImpl of IUpgradeable {
        fn upgrade(impl_hash: ClassHash) {
            _upgrade(impl_hash);
        }

        fn upgrade_and_call(impl_hash: ClassHash, selector: felt252, calldata: Array<felt252>) {
            _upgrade_and_call(impl_hash, selector, calldata);
        }
    }

    #[external]
    fn upgrade(impl_hash: ClassHash) {
        UpgradeableImpl::upgrade(impl_hash);
    }

    #[external]
    fn upgrade_and_call(impl_hash: ClassHash, selector: felt252, calldata: Array<felt252>) {
        UpgradeableImpl::upgrade_and_call(impl_hash, selector, calldata);
    }

    //
    // Unprotected
    //

    #[internal]
    fn _upgrade(impl_hash: ClassHash) {
        assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
        starknet::replace_class_syscall(impl_hash).unwrap_syscall();
        Upgraded(impl_hash);
    }

    #[internal]
    fn _upgrade_and_call(impl_hash: ClassHash, selector: felt252, calldata: Array<felt252>) {
        _upgrade(impl_hash);
        // The call_contract syscall is used in order to call a selector from the new class.
        // See: https://docs.starknet.io/documentation/architecture_and_concepts/Contracts/system-calls-cairo1/#replace_class
        starknet::call_contract_syscall(get_contract_address(), selector, calldata.span())
            .unwrap_syscall();
    }
}
