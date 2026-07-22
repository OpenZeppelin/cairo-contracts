# declare_and_deploy_at

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e595c322b51f702363311a93b1e15f172083aa65/packages/testing/src/deployment.cairo#L60-L65'> [source code] </a>

Combines the declaration of a class and the deployment of a contract at the given address
into one function call.
This function will skip declaration if the contract is
already declared (the result of `snforge_std::declare` call is of type
`DeclareResult::AlreadyDeclared`)

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[deployment](./openzeppelin_testing-deployment.md)::[declare_and_deploy_at](./openzeppelin_testing-deployment-declare_and_deploy_at.md)

<pre><code class="language-cairo">pub fn declare_and_deploy_at(
    contract_name: ByteArray, target_address: ContractAddress, calldata: Array&lt;felt252&gt;,
)</code></pre>

