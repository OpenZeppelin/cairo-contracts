## Presets

> **NOTE:** This document is better viewed at [https://docs.openzeppelin.com/contracts-cairo/presets](https://docs.openzeppelin.com/contracts-cairo/3.x/presets)

Presets are ready-to-deploy contracts that combine widely used components into simple,
general-purpose configurations.

Use [Wizard for Cairo](https://wizard.openzeppelin.com/cairo), our code-generation tool, to build
custom combinations of components.

`MultisigAccountUpgradeable` provides quorum-based STARK-curve authorization through SRC6,
outside execution through SRC9, and self-authorized class upgrades. The current signer quorum
authorizes signer, quorum, and implementation changes through account self-calls. Its signatures
use the canonical `[1, n, public_key_1, r_1, s_1, ..., public_key_n, r_n, s_n]` encoding described
in the [account API](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#MultisigAccountComponent).

### Presets

- [`AccountUpgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#AccountUpgradeable)
- [`ERC20Upgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/erc20#ERC20Upgradeable)
- [`ERC721Upgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/erc721#ERC721Upgradeable)
- [`ERC1155Upgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/erc1155#ERC1155Upgradeable)
- [`EthAccountUpgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#EthAccountUpgradeable)
- [`MultisigAccountUpgradeable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#MultisigAccountUpgradeable)
- [`UniversalDeployer`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/udc#UniversalDeployer)
