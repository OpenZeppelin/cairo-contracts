# AsAddressTrait

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e4c5e434fb1cf8890b0c6b577e194876449e1d48/packages/testing/src/constants.cairo#L141-L151'> [source code] </a>

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[constants](./openzeppelin_testing-constants.md)::[AsAddressTrait](./openzeppelin_testing-constants-AsAddressTrait.md)

<pre><code class="language-cairo">pub trait AsAddressTrait</code></pre>

## Trait functions

### as_address

Converts a felt252 to a ContractAddress as a constant function.

Requirements:
- `value` must be a valid contract address.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[constants](./openzeppelin_testing-constants.md)::[AsAddressTrait](./openzeppelin_testing-constants-AsAddressTrait.md)::[as_address](./openzeppelin_testing-constants-AsAddressTrait.md#as_address)

<pre><code class="language-cairo">fn as_address(self: felt252) -&gt; ContractAddress</code></pre>


