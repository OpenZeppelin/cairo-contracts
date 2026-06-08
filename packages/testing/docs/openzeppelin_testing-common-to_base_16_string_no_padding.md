# to_base_16_string_no_padding

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e4c5e434fb1cf8890b0c6b577e194876449e1d48/packages/testing/src/common.cairo#L37-L40'> [source code] </a>

Converts a `felt252` to a `base16` (hexadecimal) string without padding, but including the `0x`
prefix.
We need this because Starknet Foundry has a way of representing addresses and selectors that
does not include 0's after `0x`.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[common](./openzeppelin_testing-common.md)::[to_base_16_string_no_padding](./openzeppelin_testing-common-to_base_16_string_no_padding.md)

<pre><code class="language-cairo">pub fn to_base_16_string_no_padding(value: felt252) -&gt; ByteArray</code></pre>

