use openzeppelin_access::ownable::OwnableComponent::OwnershipTransferred;
use openzeppelin_access::ownable::OwnableComponent;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::test_utils;
use starknet::ContractAddress;

pub fn assert_only_event_ownership_transferred(
    contract: ContractAddress, previous_owner: ContractAddress, new_owner: ContractAddress
) {
    assert_event_ownership_transferred(contract, previous_owner, new_owner);
    test_utils::assert_no_events_left(contract);
}

pub fn assert_event_ownership_transferred(
    contract: ContractAddress, previous_owner: ContractAddress, new_owner: ContractAddress
) {
    let event = test_utils::pop_log::<OwnableComponent::Event>(contract).unwrap();
    let expected = OwnableComponent::Event::OwnershipTransferred(
        OwnershipTransferred { previous_owner, new_owner }
    );
    assert!(event == expected);

    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnershipTransferred"));
    indexed_keys.append_serde(previous_owner);
    indexed_keys.append_serde(new_owner);
    test_utils::assert_indexed_keys(event, indexed_keys.span());
}
