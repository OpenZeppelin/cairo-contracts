use snforge_std::cheatcodes::events::EventFetcher;
use snforge_std::{spy_events, SpyOn, Event, EventSpy, EventAssertions};
use starknet::ContractAddress;

pub fn spy_on(contract_address: ContractAddress) -> EventSpy {
    spy_events(SpyOn::One(contract_address))
}

#[generate_trait]
pub impl EventSpyExtImpl of EventSpyExt {
    fn assert_only_event<T, +starknet::Event<T>, +Drop<T>>(
        ref self: EventSpy, from_address: ContractAddress, event: T
    ) {
        self.assert_emitted_single(from_address, event);
        self.assert_no_events_left_from(from_address);
    }

    fn assert_emitted_single<T, +starknet::Event<T>, +Drop<T>>(
        ref self: EventSpy, from_address: ContractAddress, expected_event: T
    ) {
        self.assert_emitted(@array![(from_address, expected_event)]);
    }

    fn drop_event_from(ref self: EventSpy, from_address: ContractAddress) {
        self.drop_events_from(from_address, 1);
    }

    fn drop_all_events(ref self: EventSpy) {
        self.fetch_events();
        self.events = array![];
    }

    fn drop_all_events_from(ref self: EventSpy, from_address: ContractAddress) {
        self.fetch_events();
        let mut new_events: Array<(ContractAddress, Event)> = array![];
        while let Option::Some((from, event)) = self
            .events
            .pop_front() {
                if from != from_address {
                    new_events.append((from, event));
                }
            };
        self.events = new_events;
    }

    fn drop_events_from(ref self: EventSpy, from_address: ContractAddress, number_to_drop: u32) {
        self.fetch_events();
        let mut dropped_number = 0;
        let mut new_events: Array<(ContractAddress, Event)> = array![];
        while let Option::Some((from, event)) = self
            .events
            .pop_front() {
                if from == from_address && dropped_number < number_to_drop {
                    dropped_number += 1;
                } else {
                    new_events.append((from, event));
                }
            };
        assert!(
            number_to_drop == dropped_number,
            "Event utils: Expected to drop ${number_to_drop}, actual ${dropped_number}"
        );
        self.events = new_events;
    }

    fn assert_no_events_left(ref self: EventSpy) {
        self.fetch_events();
        assert!(self.events.len() == 0, "Events remaining on queue");
    }

    fn assert_no_events_left_from(ref self: EventSpy, from_address: ContractAddress) {
        self.fetch_events();
        assert!(self.count_events_from(from_address) == 0, "Events remaining on queue");
    }

    fn count_events_from(self: @EventSpy, from_address: ContractAddress) -> u32 {
        let mut result = 0;
        let mut events = self.events.span();
        let mut index = 0;
        let length = events.len();
        while index < length {
            let (from, _) = events.at(index);
            if from_address == *from {
                result += 1;
            }
            index += 1;
        };
        result
    }
}
