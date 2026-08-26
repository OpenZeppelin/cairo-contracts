# declare_and_deploy

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/b9f69d8302c559ed4c0e17d5e8763142ee49a865/packages/testing/src/deployment.cairo#L47-L50'> [source code] </a>

Combines the declaration of a class and the deployment of a contract into one function call.
This function will skip declaration if the contract is
already declared (the result of `snforge_std::declare` call is of type
`DeclareResult::AlreadyDeclared`)

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[deployment](./openzeppelin_testing-deployment.md)::[declare_and_deploy](./openzeppelin_testing-deployment-declare_and_deploy.md)

<pre><code class="language-cairo">pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array&lt;felt252&gt;) -&gt; ContractAddress</code></pre>

