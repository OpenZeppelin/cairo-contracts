use snforge_std::cheatcodes::events::remove_event;
use snforge_std::{declare, ContractClassTrait, spy_events, EventSpy, SpyOn};
use starknet::ContractAddress;

pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare(contract_name).unwrap();
    match contract_class.deploy(@calldata) {
        Result::Ok((contract_address, _)) => contract_address,
        Result::Err(panic_data) => panic!("Failed to deploy, error: ${:?}", panic_data)
    }
}

pub fn declare_and_deploy_at(
    contract_name: ByteArray, target_address: ContractAddress, calldata: Array<felt252>
) {
    let contract_class = declare(contract_name).unwrap();
    if let Result::Err(panic_data) = contract_class.deploy_at(@calldata, target_address) {
        panic!("Failed to deploy, error: ${:?}", panic_data)
    }
}

pub fn spy_on(contract_address: ContractAddress) -> EventSpy {
    spy_events(SpyOn::One(contract_address))
}

pub fn assert_no_events_left(ref spy: EventSpy) {
    assert(spy.events.len() == 0, 'Events remaining on queue');
}

pub fn drop_event(ref spy: EventSpy) {
    let len = spy.events.len();

    if len > 0 {
        remove_event(ref spy, len - 1);
    }
}

pub fn drop_events(ref spy: EventSpy, n_events: felt252) {
    let mut count = n_events;
    loop {
        if count == 0 {
            break;
        }
        drop_event(ref spy);
        count -= 1;
    }
}
