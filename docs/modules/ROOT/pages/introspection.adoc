# Introspection

> Expect this module to evolve.

## Table of Contents

* [ERC165](#erc165)
  * [Interface calculations](#interface-calculations)
  * [Registering interfaces](#registering-interfaces)
  * [Querying interfaces](#querying-interfaces)
  * [IERC165](#ierc165)
  * [IERC165 API Specification](#ierc165-api-specification)
    * [`supportsInterface`](#supportsinterface)
  * [ERC165 Library Functions](#erc165-library-functions)
    * [`supports_interface`](#supportsinterface2)
    * [`register_interface`](#register_interface)

## ERC165

The ERC165 standard allows smart contracts to exercise [type introspection](https://en.wikipedia.org/wiki/Type_introspection) on other contracts, that is, examining which functions can be called on them. This is usually referred to as a contract’s interface.

Cairo contracts, like Ethereum contracts, have no native concept of an interface, so applications must usually simply trust they are not making an incorrect call. For trusted setups this is a non-issue, but often unknown and untrusted third-party addresses need to be interacted with. There may even not be any direct calls to them! (e.g. ERC20 tokens may be sent to a contract that lacks a way to transfer them out of it, locking them forever). In these cases, a contract declaring its interface can be very helpful in preventing errors.

It should be noted that the [constants library](../src/openzeppelin/utils/constants.cairo) includes constant variables referencing all of the interface ids used in these contracts. This allows for more legible code i.e. using `IERC165_ID` instead of `0x01ffc9a7`.

### Interface calculations

In order to ensure EVM/StarkNet compatibility, interface identifiers are not calculated on StarkNet. Instead, the interface IDs are hardcoded from their EVM calculations. On the EVM, the interface ID is calculated from the selector's first four bytes of the hash of the function's signature while Cairo selectors are 252 bytes long. Due to this difference, hardcoding EVM's already-calculated interface IDs is the most consistent approach to both follow the EIP165 standard and EVM compatibility.

### Registering interfaces

For a contract to declare its support for a given interface, the contract should import the ERC165 library and register its support. It's recommended to register interface support upon contract deployment through a constructor either directly or indirectly (as an initializer) like this:

```cairo
from openzeppelin.introspection.ERC165 import ERC165

INTERFACE_ID = 0x12345678

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    ERC165.register_interface(INTERFACE_ID)
    return ()
end
```

### Querying interfaces

To query a target contract's support for an interface, the querying contract should call `supportsInterface` through IERC165 with the target contract's address and the queried interface id. Here's an example:

```cairo
from openzeppelin.introspection.IERC165 import IERC165

INTERFACE_ID = 0x12345678

func check_support{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        target_contract: felt,
    ) -> (success: felt):
    let (is_supported) = IERC165.supportsInterface(target_contract, INTERFACE_ID)
    return (is_supported)
end
```

> Please note that `supportsInterface` is camelCased because it is an exposed contract method as part of ERC165's interface. This differs from library methods (such as `supports_interface` from the [ERC165 library](../src/openzeppelin/introspection/ERC165.cairo)) which are snake_cased and not exposed. See the [Function names and coding style](../docs/Extensibility.md#function-names-and-coding-style) for more details.

### IERC165

```cairo
@contract_interface
namespace IERC165:
    func supportsInterface(interfaceId: felt) -> (success: felt):
    end
end
```

### IERC165 API Specification

```cairo
func supportsInterface(interfaceId: felt) -> (success: felt):
end
```

#### `supportsInterface`

Returns true if this contract implements the interface defined by `interfaceId`.

Parameters:

```cairo
interfaceId: felt
```

Returns:

```cairo
success: felt
```

### ERC165 Library Functions

```cairo
func supports_interface(interface_id: felt) -> (success: felt):
end

func register_interface(interface_id: felt):
end
```

<h4 id="supportsinterface2"><code>supports_interface</code></h4>

Returns true if this contract implements the interface defined by `interface_id`.

Parameters:

```cairo
interface_id: felt
```

Returns:

```cairo
success: felt
```

#### `register_interface`

Calling contract declares support for a specific interface defined by `interface_id`.

Parameters:

```cairo
interface_id: felt
```

Returns:

None.
