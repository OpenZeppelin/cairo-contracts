# declare_and_deploy

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e4c5e434fb1cf8890b0c6b577e194876449e1d48/packages/testing/src/deployment.cairo#L50-L53'> [source code] </a>

Combines the declaration of a class and the deployment of a contract into one function call.
This function will skip declaration if the contract is
already declared (the result of `snforge_std::declare` call is of type
`DeclareResult::AlreadyDeclared`)

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[deployment](./openzeppelin_testing-deployment.md)::[declare_and_deploy](./openzeppelin_testing-deployment-declare_and_deploy.md)

<pre><code class="language-cairo">pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array&lt;felt252&gt;) -&gt; ContractAddress</code></pre>

