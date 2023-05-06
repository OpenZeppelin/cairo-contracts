use starknet::class_hash::ClassHash;

#[abi]
trait IUpgradeable {
    fn upgrade(impl_hash: ClassHash);
    fn upgrade_and_call(impl_hash: ClassHash, selector: felt252, calldata: Array<felt252>);
}

#[contract]
mod Upgradeable {
    use array::ArrayTrait;
    use starknet::{
        class_hash::{ ClassHash, ClassHashZeroable},
        ContractAddress,
        get_contract_address,
        syscalls::{ call_contract_syscall, replace_class_syscall }
    };
    use zeroable::Zeroable;

    #[event]
    fn Upgraded(implementation: ClassHash) {}

    //
    // Unprotected
    //

    #[internal]
    fn _upgrade(impl_hash: ClassHash) {
        assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
        replace_class_syscall(impl_hash).unwrap_syscall();
        Upgraded(impl_hash);
    }

    #[internal]
    fn _upgrade_and_call(impl_hash: ClassHash, selector: felt252, calldata: Array<felt252>) {
        _upgrade(impl_hash);
        // The call_contract syscall is used in order to call a selector from the new class.
        // See: https://docs.starknet.io/documentation/architecture_and_concepts/Contracts/system-calls-cairo1/#replace_class
        call_contract_syscall(get_contract_address(), selector, calldata.span()).unwrap_syscall();
    }
}
