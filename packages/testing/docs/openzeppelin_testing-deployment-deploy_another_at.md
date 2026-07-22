# deploy_another_at

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e595c322b51f702363311a93b1e15f172083aa65/packages/testing/src/deployment.cairo#L38-L44'> [source code] </a>

Deploys a contract using the class hash from another already-deployed contract.

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[deployment](./openzeppelin_testing-deployment.md)::[deploy_another_at](./openzeppelin_testing-deployment-deploy_another_at.md)

<pre><code class="language-cairo">pub fn deploy_another_at(
    existing: ContractAddress, target_address: ContractAddress, calldata: Array&lt;felt252&gt;,
)</code></pre>

