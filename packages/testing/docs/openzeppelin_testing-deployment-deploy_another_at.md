# deploy_another_at

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e4c5e434fb1cf8890b0c6b577e194876449e1d48/packages/testing/src/deployment.cairo#L38-L44'> [source code] </a>

Deploys a contract using the class hash from another already-deployed contract.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[deployment](./openzeppelin_testing-deployment.md)::[deploy_another_at](./openzeppelin_testing-deployment-deploy_another_at.md)

<pre><code class="language-cairo">pub fn deploy_another_at(
    existing: ContractAddress, target_address: ContractAddress, calldata: Array&lt;felt252&gt;,
)</code></pre>

