# declare_class

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e595c322b51f702363311a93b1e15f172083aa65/packages/testing/src/deployment.cairo#L9-L17'> [source code] </a>

Declares a contract with a `snforge_std::declare` call and unwraps the result.
This function will skip declaration and just return the `ContractClass` if the contract is
already declared (the result of `snforge_std::declare` call is of type
`DeclareResult::AlreadyDeclared`)

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[deployment](./openzeppelin_testing-deployment.md)::[declare_class](./openzeppelin_testing-deployment-declare_class.md)

<pre><code class="language-cairo">pub fn declare_class(contract_name: ByteArray) -&gt; ContractClass</code></pre>

