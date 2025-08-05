# openzeppelin_testing

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)


## [Modules](./openzeppelin_testing-modules.md)

| | |
|:---|:---|
| [common](./openzeppelin_testing-common.md) | — |
| [constants](./openzeppelin_testing-constants.md) | — |
| [deployment](./openzeppelin_testing-deployment.md) | — |
| [events](./openzeppelin_testing-events.md) | — |
| [signing](./openzeppelin_testing-signing.md) | — |


---
 
# Re-exports: 

 - ### Free functions

| | |
|:---|:---|
| [assert_entrypoint_not_found_error](./openzeppelin_testing-common-assert_entrypoint_not_found_error.md) | Asserts that the syscall result of a call failed with an "Entrypoint not found" error, following the Starknet Foundry emitted error format. |
| [panic_data_to_byte_array](./openzeppelin_testing-common-panic_data_to_byte_array.md) | Converts panic data into a string (ByteArray). `panic_data`  is expected to be a valid serialized byte array with an extra felt252 at the beginning, which is the BYTE_ARRAY_MAGIC. |
| [to_base_16_string](./openzeppelin_testing-common-to_base_16_string.md) | Converts a `felt252`  to a `base16`  string padded to 66 characters including the `0x`  prefix. |
| [declare_and_deploy](./openzeppelin_testing-deployment-declare_and_deploy.md) | Combines the declaration of a class and the deployment of a contract into one function call. This function will skip declaration if the contract is already declared (the result of... |
| [declare_and_deploy_at](./openzeppelin_testing-deployment-declare_and_deploy_at.md) | Combines the declaration of a class and the deployment of a contract at the given address into one function call. This function will skip declaration if the contract is... |
| [declare_class](./openzeppelin_testing-deployment-declare_class.md) | Declares a contract with a `snforge_std::declare`  call and unwraps the result. This function will skip declaration and just return the `ContractClass`  if the contract is... |
| [deploy](./openzeppelin_testing-deployment-deploy.md) | Deploys an instance of a contract and unwraps the result. |
| [deploy_another_at](./openzeppelin_testing-deployment-deploy_another_at.md) | Deploys a contract using the class hash from another already-deployed contract. |
| [deploy_at](./openzeppelin_testing-deployment-deploy_at.md) | Deploys a contract at the given address and unwraps the result. |
| [spy_events](./openzeppelin_testing-events-spy_events.md) | Creates a new `EventSpyQueue`  instance. |

<br>


 - ### Structs

| | |
|:---|:---|
| [EventSpyQueue](./openzeppelin_testing-events-EventSpyQueue.md) | A wrapper around the `EventSpy`  structure to allow treating the events as a queue. |

<br>


 - ### Traits

| | |
|:---|:---|
| [IntoBase16StringTrait](./openzeppelin_testing-common-IntoBase16StringTrait.md) | — |
| [AsAddressTrait](./openzeppelin_testing-constants-AsAddressTrait.md) | — |
| [EventSpyExt](./openzeppelin_testing-events-EventSpyExt.md) | — |

<br>


 - ### Impls

| | |
|:---|:---|
| [FuzzableBool](./openzeppelin_testing-common-FuzzableBool.md) | An implementation of Fuzzable trait to support boolean parameters in fuzz tests. |
| [FuzzableContractAddress](./openzeppelin_testing-common-FuzzableContractAddress.md) | An implementation of Fuzzable trait to support ContractAddress parameters in fuzz tests. |

<br>

