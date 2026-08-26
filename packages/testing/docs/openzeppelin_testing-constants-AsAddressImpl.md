# AsAddressImpl

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/b9f69d8302c559ed4c0e17d5e8763142ee49a865/packages/testing/src/constants.cairo#L141-L151'> [source code] </a>

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[constants](./openzeppelin_testing-constants.md)::[AsAddressImpl](./openzeppelin_testing-constants-AsAddressImpl.md)

<pre><code class="language-cairo">pub impl AsAddressImpl of AsAddressTrait;</code></pre>

## Impl functions

### as_address

Converts a felt252 to a ContractAddress as a constant function.

Requirements:
- `value` must be a valid contract address.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[constants](./openzeppelin_testing-constants.md)::[AsAddressImpl](./openzeppelin_testing-constants-AsAddressImpl.md)::[as_address](./openzeppelin_testing-constants-AsAddressImpl.md#as_address)

<pre><code class="language-cairo">fn as_address(self: felt252) -&gt; ContractAddress</code></pre>


