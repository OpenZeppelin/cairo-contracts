# EventSpyQueueImpl

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)

<pre><code class="language-cairo">pub impl EventSpyQueueImpl of EventSpyExt;</code></pre>

## Impl functions

### get_events

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[get_events](./openzeppelin_testing-events-EventSpyQueueImpl.md#get_events)

<pre><code class="language-cairo">fn get_events(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>) -&gt; Events</code></pre>


### assert_only_event

Ensures that `from_address` has emitted only the `expected_event` and no additional events.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[assert_only_event](./openzeppelin_testing-events-EventSpyQueueImpl.md#assert_only_event)

<pre><code class="language-cairo">fn assert_only_event(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>, from_address: ContractAddress, expected_event: T)</code></pre>


### assert_emitted_single

Ensures that `from_address` has emitted the `expected_event`.
This assertion increments the event offset which essentially
consumes the event in the first position of the offset. This means
that events must be asserted in the order that they're emitted.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[assert_emitted_single](./openzeppelin_testing-events-EventSpyQueueImpl.md#assert_emitted_single)

<pre><code class="language-cairo">fn assert_emitted_single(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>, from_address: ContractAddress, expected_event: T)</code></pre>


### drop_event

Removes a single event from the queue. If the queue is empty, the function will panic.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[drop_event](./openzeppelin_testing-events-EventSpyQueueImpl.md#drop_event)

<pre><code class="language-cairo">fn drop_event(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>)</code></pre>


### drop_n_events

Removes `number_to_drop` events from the queue. If the queue is empty, the function will
panic.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[drop_n_events](./openzeppelin_testing-events-EventSpyQueueImpl.md#drop_n_events)

<pre><code class="language-cairo">fn drop_n_events(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>, number_to_drop: u32)</code></pre>


### drop_all_events

Removes all events remaining on the queue. If the queue is empty already, the function will
do nothing.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[drop_all_events](./openzeppelin_testing-events-EventSpyQueueImpl.md#drop_all_events)

<pre><code class="language-cairo">fn drop_all_events(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>)</code></pre>


### assert_no_events_left

Ensures that there are no events remaining on the queue.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[assert_no_events_left](./openzeppelin_testing-events-EventSpyQueueImpl.md#assert_no_events_left)

<pre><code class="language-cairo">fn assert_no_events_left(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>)</code></pre>


### assert_no_events_left_from

Ensures that there are no events emitted from the given address remaining on the queue.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[assert_no_events_left_from](./openzeppelin_testing-events-EventSpyQueueImpl.md#assert_no_events_left_from)

<pre><code class="language-cairo">fn assert_no_events_left_from(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>, from_address: ContractAddress)</code></pre>


### count_events_from

Counts the number of remaining events emitted from the given address.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueueImpl](./openzeppelin_testing-events-EventSpyQueueImpl.md)::[count_events_from](./openzeppelin_testing-events-EventSpyQueueImpl.md#count_events_from)

<pre><code class="language-cairo">fn count_events_from(ref self: <a href="openzeppelin_testing-events-EventSpyQueue.html">EventSpyQueue</a>, from_address: ContractAddress) -&gt; u32</code></pre>


