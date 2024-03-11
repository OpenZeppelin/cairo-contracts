mod constants;

use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::testing;

fn deploy(contract_class_hash: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (address, _) = starknet::deploy_syscall(
        contract_class_hash.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap_syscall();
    address
}

fn deploy_with_salt(
    contract_class_hash: felt252, calldata: Array<felt252>, salt: felt252
) -> ContractAddress {
    let (address, _) = starknet::deploy_syscall(
        contract_class_hash.try_into().unwrap(), salt, calldata.span(), false
    )
        .unwrap_syscall();
    address
}

/// Pop the earliest unpopped logged event enum for the contract and checks
/// there's no more keys or data left on the event, preventing unaccounted params.
///
/// CAUTION: If the event enum contains two `flat` events with the same structure (member types),
/// this function will always match the first event, even when the second one is emitted.
fn pop_log<T, +Drop<T>, +starknet::Event<T>>(address: ContractAddress) -> Option<T> {
    let (mut keys, mut data) = testing::pop_log_raw(address)?;

    let ret = starknet::Event::deserialize(ref keys, ref data);
    assert!(data.is_empty(), "Event has extra data");
    assert!(keys.is_empty(), "Event has extra keys");
    ret
}

/// Asserts that `expected_keys` exactly matches the indexed keys from `event`.
///
/// `expected_keys` must include all indexed event keys for `event` in the order
/// that they're defined.
///
/// If the event is not flattened, the first key will be the event member name
/// e.g. selector!("EnumMemberName").
fn assert_indexed_keys<T, +Drop<T>, +starknet::Event<T>>(event: T, expected_keys: Span<felt252>) {
    let mut keys = array![];
    let mut data = array![];

    event.append_keys_and_data(ref keys, ref data);
    assert!(expected_keys == keys.span());
}

fn assert_no_events_left(address: ContractAddress) {
    assert!(testing::pop_log_raw(address).is_none(), "Events remaining on queue");
}

fn drop_event(address: ContractAddress) {
    let _ = testing::pop_log_raw(address);
}

fn drop_events(address: ContractAddress, count: felt252) {
    let mut _count = count;
    loop {
        if _count == 0 {
            break;
        }
        drop_event(address);
        _count -= 1;
    }
}
