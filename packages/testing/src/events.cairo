use snforge_std::{EventSpy, EventSpyAssertionsTrait, EventSpyTrait};
use starknet::ContractAddress;

#[generate_trait]
pub impl EventSpyExtImpl of EventSpyExt {
    /// Ensures that `from_address` has emitted only the `expected_event` and no additional events.
    fn assert_only_event<T, +starknet::Event<T>, +Drop<T>>(
        ref self: EventSpy, from_address: ContractAddress, expected_event: T,
    ) {
        self.assert_emitted_single(from_address, expected_event);
        self.assert_no_events_left_from(from_address);
    }

    /// Ensures that `from_address` has emitted the `expected_event`.
    /// This assertion increments the event offset which essentially
    /// consumes the event in the first position of the offset. This means
    /// that events must be asserted in the order that they're emitted.
    fn assert_emitted_single<T, +starknet::Event<T>, +Drop<T>>(
        ref self: EventSpy, from_address: ContractAddress, expected_event: T,
    ) {
        self.assert_emitted(@array![(from_address, expected_event)]);
        self._event_offset += 1;
    }

    /// Removes a single event from the queue. If the queue is empty, the function will panic.
    fn drop_event(ref self: EventSpy) {
        self.drop_n_events(1);
    }

    /// Removes `number_to_drop` events from the queue. If the queue is empty, the function will
    /// panic.
    fn drop_n_events(ref self: EventSpy, number_to_drop: u32) {
        let events = self.get_events().events;
        let len = events.len();
        assert!(
            len >= number_to_drop,
            "Not enough events to drop. ${len} events, ${number_to_drop} to drop",
        );
        self._event_offset += number_to_drop;
    }

    /// Removes all events remaining on the queue. If the queue is empty already, the function will
    /// do nothing.
    fn drop_all_events(ref self: EventSpy) {
        let events = self.get_events().events;
        self._event_offset += events.len();
    }

    /// Ensures that there are no events remaining on the queue.
    fn assert_no_events_left(ref self: EventSpy) {
        let events = self.get_events().events;
        assert!(events.len() == 0, "Events remaining on queue");
    }

    /// Ensures that there are no events emitted from the given address remaining on the queue.
    fn assert_no_events_left_from(ref self: EventSpy, from_address: ContractAddress) {
        assert!(self.count_events_from(from_address) == 0, "Events remaining on queue");
    }

    /// Counts the number of remaining events emitted from the given address.
    fn count_events_from(ref self: EventSpy, from_address: ContractAddress) -> u32 {
        let mut result = 0;
        let mut events = self.get_events().events;
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
