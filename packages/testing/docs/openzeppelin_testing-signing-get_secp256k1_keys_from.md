# get_secp256k1_keys_from

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e595c322b51f702363311a93b1e15f172083aa65/packages/testing/src/signing.cairo#L18-L20'> [source code] </a>

Builds a Secp256k1 Key Pair from a private key represented by a `u256` value.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[signing](./openzeppelin_testing-signing.md)::[get_secp256k1_keys_from](./openzeppelin_testing-signing-get_secp256k1_keys_from.md)

<pre><code class="language-cairo">pub fn get_secp256k1_keys_from(private_key: u256) -&gt; KeyPair&lt;u256, Secp256k1Point&gt;</code></pre>

