## Presets

> **NOTE:** This document is better viewed at [https://docs.openzeppelin.com/contracts-cairo/presets](https://docs.openzeppelin.com/contracts-cairo/3.x/presets)

Presets are ready-to-deploy contracts provided by the library. Since presets are intended to be very simple and as
generic as possible, there’s no support for custom or complex contracts such as `ERC20Pausable` or `ERC721Mintable`.

For contract customization and combination of modules you can use
[Wizard for Cairo](https://wizard.openzeppelin.com/cairo), our code-generation tool.

The Falcon-512 account presets support SRC9 outside execution, self-authorized class upgrades, and
owner-authorized key rotation. Build their deployable artifacts with
`scarb --release build -p openzeppelin_presets`; their Falcon verification paths require the
release compiler profile.

> **WARNING:** The Falcon presets use contract-specific public-key and signature encodings for the
> FALCON submission verification relation. They are not FN-DSA (FIPS 206) implementations.

### Presets

- [`AccountUpgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#AccountUpgradeable)
- [`ERC20Upgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/erc20#ERC20Upgradeable)
- [`ERC721Upgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/erc721#ERC721Upgradeable)
- [`ERC1155Upgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/erc1155#ERC1155Upgradeable)
- [`EthAccountUpgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#EthAccountUpgradeable)
- [`Falcon512ShakeAccountUpgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#Falcon512ShakeAccountUpgradeable)
- [`Falcon512ShakeDirectAccountUpgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#Falcon512ShakeDirectAccountUpgradeable)
- [`UniversalDeployer`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/udc#UniversalDeployer)
