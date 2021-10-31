# Accounts

This set of contracts and utilities implement an Account on [Starknet](https://www.cairo-lang.org/docs/hello_starknet/intro.html) using [Cairo](https://www.cairo-lang.org/docs/hello_cairo/index.html#hello-cairo).

## Core

### Account

    account = await starknet.deploy("contracts/Account.cairo")
    
An account initialized with a public key. Accounts are transferable.



#### Functions

initialize

get_public_key

get_address

get_nonce

set_public_key

is_valid_signature

execute


#### Code Sample

    starknet = await Starknet.empty()
    account = await starknet.[deploy("contracts/Account.cairo")
    await account.initialize({public_key}, account.contract_address).invoke()

    # transfer account
    assert await account.get_public_key().call() == (signer.public_key,)
    await signer.send_transaction(account, account.contract_address, 'set_public_key', [other.public_key])

## Extensions

### Initializable

    initializable = await starknet.deploy("contracts/Initializable.cairo")

An account that can have an initialized state that is set once

#### Functions

initialized

initialize
