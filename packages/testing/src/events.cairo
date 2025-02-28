use snforge_std::{EventSpy, EventSpyAssertionsTrait, EventSpyTrait, spy_events};
use starknet::ContractAddress;

#[generate_trait]
pub impl EventSpyExtImpl of EventSpyExt {
    /// Ensures that `from_address` has emitted only the `expected_event` and no additional events.
    fn assert_only_event<T, +starknet::Event<T>, +Drop<T>>(
        ref self: EventSpy, from_address: ContractAddress, expected_event: T,
    ) {
        self.assert_emitted_single(from_address, expected_event);
        self.assert_only_one_event_from(from_address);
    }

    /// Ensures that `from_address` has emitted the `expected_event`.
    /// This assertion increments the event offset which essentially
    /// consumes the event in the first position of the offset. This means
    /// that events must be asserted in the order that they're emitted.
    fn assert_emitted_single<T, +starknet::Event<T>, +Drop<T>>(
        ref self: EventSpy, from_address: ContractAddress, expected_event: T,
    ) {
        self.assert_emitted(@array![(from_address, expected_event)]);
    }

    /// Drops all remaining events from the queue by reinitializing the spy.
    fn drop_all_events(ref self: EventSpy) {
        self = spy_events();
    }

    /// Ensures that there are no events remaining on the queue.
    fn assert_no_events_left(ref self: EventSpy) {
        let events = self.get_events().events;
        assert_eq!(events.len(), 0);
    }

    /// Ensures that there are no events emitted from the given address.
    fn assert_no_events_from(ref self: EventSpy, from_address: ContractAddress) {
        assert_eq!(self.count_events_from(from_address), 0);
    }

    /// Ensures that the number of events emitted from the given address is equal to `expected`.
    fn assert_number_of_events_from(
        ref self: EventSpy, from_address: ContractAddress, expected: u32,
    ) {
        assert_eq!(self.count_events_from(from_address), expected);
    }

    /// Ensures that there's only one event emitted from the given address.
    fn assert_only_one_event_from(ref self: EventSpy, from_address: ContractAddress) {
        self.assert_only_one_event_from(from_address);
    }

    /// Counts the number of events emitted from the given address.
    fn count_events_from(ref self: EventSpy, from_address: ContractAddress) -> u32 {
        let mut result = 0;
        let mut events = self.get_events().events;
        let length = events.len();
        for i in 0..length {
            let (from, _) = events.at(i);
            if from_address == *from {
                result += 1;
            }
        };
        result
    }
}
