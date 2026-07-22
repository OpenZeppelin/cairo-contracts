# ExpectedEventTrait

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e595c322b51f702363311a93b1e15f172083aa65/packages/testing/src/events.cairo#L135-L155'> [source code] </a>

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[ExpectedEventTrait](./openzeppelin_testing-events-ExpectedEventTrait.md)

<pre><code class="language-cairo">pub trait ExpectedEventTrait</code></pre>

## Trait functions

### new

Creates a new `Event` with empty `keys` and `data` arrays.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[ExpectedEventTrait](./openzeppelin_testing-events-ExpectedEventTrait.md)::[new](./openzeppelin_testing-events-ExpectedEventTrait.md#new)

<pre><code class="language-cairo">fn new() -&gt; Event</code></pre>


### key

Serializes the given value and appends it to the `keys` array.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[ExpectedEventTrait](./openzeppelin_testing-events-ExpectedEventTrait.md)::[key](./openzeppelin_testing-events-ExpectedEventTrait.md#key)

<pre><code class="language-cairo">fn key&lt;T, +Serde&lt;T&gt;, +Drop&lt;T&gt;&gt;(self: Event, value: T) -&gt; Event</code></pre>


### data

Serializes the given value and appends it to the `data` array.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[events](./openzeppelin_testing-events.md)::[ExpectedEventTrait](./openzeppelin_testing-events-ExpectedEventTrait.md)::[data](./openzeppelin_testing-events-ExpectedEventTrait.md#data)

<pre><code class="language-cairo">fn data&lt;T, +Serde&lt;T&gt;, +Drop&lt;T&gt;&gt;(self: Event, value: T) -&gt; Event</code></pre>


