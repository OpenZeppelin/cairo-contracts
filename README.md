# OpenZeppelin Cairo Contracts

## Quickstart

A mashup between [Cairo's quickstart](https://www.cairo-lang.org/docs/quickstart.html#) and [StarkWare's intro](https://www.cairo-lang.org/docs/hello_starknet/intro.html).

### 1. Install Cairo
We recommend working inside a python virtual environment, but you can also install the Cairo package directly. To create and enter the virtual environment, type:

```bash
python3.7 -m venv ~/cairo_venv
source ~/cairo_venv/bin/activate
```

Make sure the venv is activated – you should see (cairo_venv) in the command line prompt.

Make sure you can install the following pip packages: `ecdsa`, `fastecdsa`, `sympy` (using `pip3 install ecdsa fastecdsa sympy`). On Ubuntu, for example, you will have to first run:

```bash
sudo apt install -y libgmp3-dev
```

On Mac, you can use brew:

```bash
brew install gmp
```

Download the python package (cairo-lang-0.3.1.zip) from https://github.com/starkware-libs/cairo-lang/releases/tag/v0.3.1. To install it using `pip`, run:

```bash
pip3 install cairo-lang-0.3.1.zip
```

Cairo was tested with python3.7. To make it work with python3.6, you will have to install `contextvars`:

```bash
pip3 install contextvars
```

### 2. Compile the contracts
```bash
starknet-compile contracts/contract.cairo \
    --output build/contract_compiled.json \
    --abi build/contract_abi.json
```

### 3. Deploy to testnet

```bash
export STARKNET_NETWORK=alpha
starknet deploy --contract build/contract_compiled.json
```

### 4. Interact with it

```bash
starknet invoke \
    --address CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function increase_balance \
    --inputs 1234
```
The result should look like:

```
Invoke transaction was sent.
Contract address: 0x039564c4f6d9f45a963a6dc8cf32737f0d51a08e446304626173fd838bd70e1c
Transaction ID: 1
```

The following command allows you to query the transaction status based on the transaction ID that you got (here you’ll have to replace `TRANSACTION_ID` with the transaction ID printed by starknet invoke):

```bash
starknet tx_status --id TRANSACTION_ID
```
The possible statuses are:

- `NOT_RECEIVED`: The transaction has not been received yet (i.e., not written to storage).
- `RECEIVED`: The transaction was received by the operator.
- `PENDING`: The transaction passed the validation and is waiting to be sent on-chain.
- `REJECTED`: The transaction failed validation and thus was skipped.
- `ACCEPTED_ONCHAIN`: The transaction was accepted on-chain.

Then we can query the balance:

```bash
starknet call \
    --address CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function get_balance
```

## License

OpenZeppelin Cairo Contracts is released under the [MIT License](LICENSE).
