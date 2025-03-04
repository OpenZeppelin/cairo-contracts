# EventSpyExt

Fully qualified path: `openzeppelin_testing::events::EventSpyExt`

```rust
pub trait EventSpyExt
```

## Trait functions

### get_events

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::get_events`

```rust
fn get_events(ref self: EventSpyQueue) -> Events
```


### assert_only_event

Ensures that `from_address` has emitted only the `expected_event` and no additional events.

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::assert_only_event`

```rust
fn assert_only_event<T, +starknet::Event<T>, +Drop<T>>(
    ref self: EventSpyQueue, from_address: ContractAddress, expected_event: T,
)
```


### assert_emitted_single

Ensures that `from_address` has emitted the `expected_event`. This assertion increments the event offset which essentially consumes the event in the first position of the offset. This means that events must be asserted in the order that they're emitted.

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::assert_emitted_single`

```rust
fn assert_emitted_single<T, +starknet::Event<T>, +Drop<T>>(
    ref self: EventSpyQueue, from_address: ContractAddress, expected_event: T,
)
```


### drop_event

Removes a single event from the queue. If the queue is empty, the function will panic.

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::drop_event`

```rust
fn drop_event(ref self: EventSpyQueue)
```


### drop_n_events

Removes `number_to_drop` events from the queue. If the queue is empty, the function will panic.

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::drop_n_events`

```rust
fn drop_n_events(ref self: EventSpyQueue, number_to_drop: u32)
```


### drop_all_events

Removes all events remaining on the queue. If the queue is empty already, the function will do nothing.

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::drop_all_events`

```rust
fn drop_all_events(ref self: EventSpyQueue)
```


### assert_no_events_left

Ensures that there are no events remaining on the queue.

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::assert_no_events_left`

```rust
fn assert_no_events_left(ref self: EventSpyQueue)
```


### assert_no_events_left_from

Ensures that there are no events emitted from the given address remaining on the queue.

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::assert_no_events_left_from`

```rust
fn assert_no_events_left_from(ref self: EventSpyQueue, from_address: ContractAddress)
```


### count_events_from

Counts the number of remaining events emitted from the given address.

Fully qualified path: `openzeppelin_testing::events::EventSpyExt::count_events_from`

```rust
fn count_events_from(ref self: EventSpyQueue, from_address: ContractAddress) -> u32
```


