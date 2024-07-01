use core::array::ArrayTrait;
use core::array::SpanTrait;
use openzeppelin::upgrades::UpgradeableComponent::Upgraded;
use openzeppelin::upgrades::UpgradeableComponent;
use snforge_std::cheatcodes::events::EventFetcher;
use snforge_std::{spy_events, SpyOn, Event, EventSpy, EventAssertions};
use starknet::{ContractAddress, ClassHash};

pub fn spy_on(contract_address: ContractAddress) -> EventSpy {
    spy_events(SpyOn::One(contract_address))
}

#[generate_trait]
pub impl EventSpyExtImpl of EventSpyExt {
    fn assert_only_event<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
        ref self: EventSpy, from: ContractAddress, event: T
    ) {
        self.assert_emitted_single(from, event);
        self.assert_no_events_left_from(from);
    }

    fn assert_emitted_single<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
        ref self: EventSpy, from: ContractAddress, expected_event: T
    ) {
        self.assert_emitted(@array![(from, expected_event)]);
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

    fn drop_events_from(
        ref self: EventSpy, contract_address: ContractAddress, number_to_drop: u32
    ) {
        self.fetch_events();
        let mut dropped_number: u32 = 0;
        let mut new_events: Array<(ContractAddress, Event)> = array![];
        while let Option::Some((from, event)) = self
            .events
            .pop_front() {
                if from == contract_address && dropped_number < number_to_drop {
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

    fn assert_no_events_left_from(ref self: EventSpy, contract_address: ContractAddress) {
        self.fetch_events();
        assert!(self.count_events_from(contract_address) == 0, "Events remaining on queue");
    }

    fn count_events_from(self: @EventSpy, from: ContractAddress) -> u32 {
        let mut result: u32 = 0;
        let mut events = self.events.span();
        while let Option::Some((from_address, _)) = events
            .pop_front() {
                if from == *from_address {
                    result += 1;
                }
            };
        result
    }
}
