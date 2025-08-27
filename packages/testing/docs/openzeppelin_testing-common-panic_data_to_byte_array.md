# panic_data_to_byte_array

Converts panic data into a string (ByteArray).
`panic_data` is expected to be a valid serialized byte array with an extra
felt252 at the beginning, which is the BYTE_ARRAY_MAGIC.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[common](./openzeppelin_testing-common.md)::[panic_data_to_byte_array](./openzeppelin_testing-common-panic_data_to_byte_array.md)

<pre><code class="language-cairo">pub fn panic_data_to_byte_array(panic_data: Array&lt;felt252&gt;) -&gt; ByteArray</code></pre>

