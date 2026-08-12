# SerializedSigning

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/881d4090ba46959cf8dbecff414b478e8bf70542/packages/testing/src/signing.cairo#L28-L30'> [source code] </a>

A helper trait that facilitates converting a signature into a serialized format.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[signing](./openzeppelin_testing-signing.md)::[SerializedSigning](./openzeppelin_testing-signing-SerializedSigning.md)

<pre><code class="language-cairo">pub trait SerializedSigning&lt;KP, M&gt;</code></pre>

## Trait functions

### serialized_sign

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[signing](./openzeppelin_testing-signing.md)::[SerializedSigning](./openzeppelin_testing-signing-SerializedSigning.md)::[serialized_sign](./openzeppelin_testing-signing-SerializedSigning.md#serialized_sign)

<pre><code class="language-cairo">fn serialized_sign(self: KP, msg: M) -&gt; Array&lt;felt252&gt;</code></pre>


