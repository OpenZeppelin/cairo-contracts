# EventSpyQueue

A wrapper around the `EventSpy` structure to allow treating the events as a queue.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[EventSpyQueue](./openzeppelin_testing-events-EventSpyQueue.md)

<pre><code class="language-cairo">#[derive(Drop, Serde)]
pub struct EventSpyQueue {
    event_offset: u32,
    event_spy: EventSpy,
}</code></pre>

