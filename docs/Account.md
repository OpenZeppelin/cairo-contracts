# Accounts

This set of contracts and utilities implement an Account on [Starknet](https://www.cairo-lang.org/docs/hello_starknet/intro.html) using [Cairo](https://www.cairo-lang.org/docs/hello_cairo/index.html#hello-cairo).

## Core

### Account

    account = await starknet.deploy("contracts/Account.cairo")
    
An account initialized with a public key. Accounts are transferable.

Execution of the account proof on StarkNet will validate the signature of the Account.

#### Functions

##### initialize

    $ Cairo
    func initialize (_public_key: felt, _address: felt)

    $ Python
    await account.initialize(signer.public_key, account.contract_address).invoke()

Provide the initial settings for the Account to be validatied.

###### Parameters:

_public key: felt - Pointer to Accounter Holder Public Key

_address: felt - Pointer to Account Contract Address

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr

    $ Python
    None

##### get_public_key

    assert account.get_public_key() == signer.public_key 

get the public key associated with the Account

###### Paramenters:

    None

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr
    public_key: int

    $ Python
    int: public_key

##### get_address

    assert await account.get_address().call() == (account.contract_address,)

get the contract address associated with the Account

###### Paramenters:

    None

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr

    $ Python
    int: public_key

##### get_nonce

###### Paramenters:

    None

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr

    $ Python
    int: public_key

##### set_public_key

###### Paramenters:

    None

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr

    $ Python
    int: public_key

##### is_valid_signature

###### Paramenters:

    None

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr

    $ Python
    int: public_key

##### execute

###### Paramenters:

    None

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr

    $ Python
    int: public_key


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
