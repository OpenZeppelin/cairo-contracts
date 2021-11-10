# Accounts

This set of contracts and utilities implement an Account on [Starknet](https://www.cairo-lang.org/docs/hello_starknet/intro.html) using [Cairo](https://www.cairo-lang.org/docs/hello_cairo/index.html#hello-cairo).

OpenZepplin Cairo Contracts Account Contract provides a mechanism to account authentication and replay attack protection.

The general workflow is three simple steps: 
1. Acccount contract is deployed to Starknet; 
1. Account is iitialized with a public key; and
1. Transactions are executed on the account via the Signer with each validated that the account is authenticated to perform the transaction and that the transaction is not subject to a replay attack.

### Signer

Signer is used to perform transactions on an account. To use Signer, first register a public address with the signer object.

    from utils.Signer import Signer

    signer = Signer(123456789987654321)

Then send transactions with the signer object that need to be authenticated by StarkNet.

    await signer.send_transaction(account, contract_address, 'account_command', [])

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
    contract_address : felt

    $ Python
    int: contract_address

##### get_nonce

    assert await account.get_nonce().call() == (account.nonce)

get the current transaction count or nonce for the account

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

    assert await account.get_public_key().call() == (signer.public_key,)
    await signer.send_transaction(account, account.contract_address, 'set_public_key', [other.public_key])
    assert await account.get_public_key().call() == (other.public_key,)

transfer the account from one public key to another

###### Paramenters:

    int: public_key

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr

    $ Python
    None

##### is_valid_signature

*This function is not directly used by clients. See func execute.

##### execute

Note: execute is not called directly in workflows with the Account. Instead, the Signer object is used to send_transaction which calls the execute function. Thus, one can think of send_transaction as a wrapper around execute.

execute takes a Message as its input parameter with a reference to the account. execute then:
1. confirms that the Account has been initialized
1. hashes the Message
1. sends it to Starknet to validate the signature
1. increments the nonce
1. calls the contract per the Message

###### Paramenters:

    $ Cairo
    to: felt,
    selector: felt,
    calldata_len: felt,
    calldata: felt*,
    signature_len: felt,
    signature: felt*

    $ Python
    int: to_contract_address, 
    str: selector_name, 
    list: calldata, 
    list of length 2: [sig_r, sig_s]

###### Return:

    $ Cairo
    (implicit) storage_ptr: Storage*
    (implicit) pedersen_ptr: HashBuiltin*
    (implicit) range_check_ptr

    $ Python
    int: system_response_return_data_size


#### Code Sample

Note: Starknet is stil under development and this Cairo Contracts project is still experimental. This example is designed to work in a test environment. Code samples that are more representative of a production implementation will be added when available.

    starknet = await Starknet.empty()
    account = await starknet.[deploy("contracts/Account.cairo")
    await account.initialize({public_key}, account.contract_address).invoke()

    # transfer account
    assert await account.get_public_key().call() == (signer.public_key,)
    await signer.send_transaction(account, account.contract_address, 'set_public_key', [other.public_key])
