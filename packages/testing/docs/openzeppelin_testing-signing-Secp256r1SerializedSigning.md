# Secp256r1SerializedSigning

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e4c5e434fb1cf8890b0c6b577e194876449e1d48/packages/testing/src/signing.cairo#L46-L51'> [source code] </a>

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[signing](./openzeppelin_testing-signing.md)::[Secp256r1SerializedSigning](./openzeppelin_testing-signing-Secp256r1SerializedSigning.md)

<pre><code class="language-cairo">pub impl Secp256r1SerializedSigning of SerializedSigning&lt;KeyPair&lt;u256, Secp256r1Point&gt;, u256&gt;;</code></pre>

## Impl functions

### serialized_sign

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[signing](./openzeppelin_testing-signing.md)::[Secp256r1SerializedSigning](./openzeppelin_testing-signing-Secp256r1SerializedSigning.md)::[serialized_sign](./openzeppelin_testing-signing-Secp256r1SerializedSigning.md#serialized_sign)

<pre><code class="language-cairo">fn serialized_sign(self: KeyPair&lt;u256, Secp256r1Point&gt;, msg: u256) -&gt; Array&lt;felt252&gt;</code></pre>


