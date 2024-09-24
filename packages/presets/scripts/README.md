# Declare Presets

This crate provides a script to declare all presets from the Contracts for Cairo library.

## Prerequisites

This crate is meant to deploy on the sepolia network, so a deployed account contract with funds is required.
This crate can also be tested with [starknet-devnet](https://github.com/0xSpaceShard/starknet-devnet-rs).

## Usage

`cd` into the `scripts/` directory and run the script through Starknet Foundry's [scripting feature](https://foundry-rs.github.io/starknet-foundry/starknet/script.html).
Here's the command using a starkli-style account:

```bash
sncast \
--account path/to/account.json \
--keystore path/to/key.json \
script run declare_presets \
--url http://127.0.0.1:5050
```
