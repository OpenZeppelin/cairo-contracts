use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use serde::Serde;
use serde::serialize_array_helper;
use serde::deserialize_array_helper;
use starknet::class_hash::ClassHash;
use starknet::ContractAddress;

#[abi]
trait IUniversalDeployer {
    fn deploy_contract(
        class_hash: ClassHash, salt: felt252, unique: bool, _calldata: Span<felt252>
    ) -> ContractAddress;
}

#[contract]
mod UniversalDeployer {
    use super::SpanSerde;

    use array::SpanTrait;
    use hash::pedersen;
    use starknet::class_hash::ClassHash;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use traits::Into;

    #[event]
    fn ContractDeployed(
        address: ContractAddress,
        deployer: ContractAddress,
        unique: bool,
        class_hash: ClassHash,
        _calldata: Span<felt252>,
        salt: felt252,
    ) {}

    #[external]
    fn deploy_contract(
        class_hash: ClassHash, salt: felt252, unique: bool, _calldata: Span<felt252>
    ) -> ContractAddress {
        let deployer: ContractAddress = get_caller_address();

        // Defaults for non-unique deployment
        let mut _salt: felt252 = salt;
        let mut from_zero: bool = true;

        if unique {
            _salt = pedersen(deployer.into(), salt);
            from_zero = false;
        }

        let (address, _) = starknet::deploy_syscall(
            class_hash, _salt, _calldata, from_zero
        )
            .unwrap_syscall();

        ContractDeployed(address, deployer, unique, class_hash, _calldata, salt);
        return address;
    }
}

impl SpanSerde<
    T, impl TSerde: Serde<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>
> of Serde<Span<T>> {
    fn serialize(self: @Span<T>, ref output: Array<felt252>) {
        (*self).len().serialize(ref output);
        serialize_array_helper(*self, ref output);
    }
    fn deserialize(ref serialized: Span<felt252>) -> Option<Span<T>> {
        let length = *serialized.pop_front()?;
        let mut arr = ArrayTrait::new();
        Option::Some(deserialize_array_helper(ref serialized, arr, length)?.span())
    }
}
