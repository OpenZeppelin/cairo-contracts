# FuzzableContractAddress

An implementation of Fuzzable trait to support ContractAddress parameters in fuzz tests.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[common](./openzeppelin_testing-common.md)::[FuzzableContractAddress](./openzeppelin_testing-common-FuzzableContractAddress.md)

<pre><code class="language-cairo">pub impl FuzzableContractAddress of Fuzzable&lt;
    ContractAddress, DebugImpl&lt;ContractAddress, ContractAddressIntoFelt252, ContractAddressCopy&gt;,
&gt;;</code></pre>

## Impl functions

### blank

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[common](./openzeppelin_testing-common.md)::[FuzzableContractAddress](./openzeppelin_testing-common-FuzzableContractAddress.md)::[blank](./openzeppelin_testing-common-FuzzableContractAddress.md#blank)

<pre><code class="language-cairo">fn blank() -&gt; ContractAddress</code></pre>


### generate

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[common](./openzeppelin_testing-common.md)::[FuzzableContractAddress](./openzeppelin_testing-common-FuzzableContractAddress.md)::[generate](./openzeppelin_testing-common-FuzzableContractAddress.md#generate)

<pre><code class="language-cairo">fn generate() -&gt; ContractAddress</code></pre>


