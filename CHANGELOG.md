<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- ERC2981 (NFT Royalty Standard) component (#1091)
- `merkle_tree` package with utilities to verify proofs and multi proofs (#1101)

### Changed

- Bump snforge to v0.27.0 (#1107)

### Changed (Breaking)

- Changed ABI suffix to Trait in dual case account and eth account modules (#1096).
  - `DualCaseAccountABI` renamed to `DualCaseAccountTrait`
  - `DualCaseEthAccountABI` renamed to `DualCaseEthAccountTrait`
- Bump scarb to v2.7.1 (#1025)

## 0.15.1 (2024-08-13)

### Changed

- Remove token dependency from account package (#1100)
- Fix docsite links (#1094)

## 0.15.0 (2024-08-08)

### Added

- ERC721Enumerable component (#983)
- TimelockController component (#996)
- HashCall implementation (#996)
- Separated package for each submodule (#1065)
  - `openzeppelin_access`
  - `openzeppelin_account`
  - `openzeppelin_governance`
  - `openzeppelin_introspection`
  - `openzeppelin_presets`
  - `openzeppelin_security`
  - `openzeppelin_token`
  - `openzeppelin_upgrades`
  - `openzeppelin_utils`
- Separated packages intended as [dev-dependencies] (#1084)
  - `openzeppelin_testing`
  - `openzeppelin_test_common`

### Changed

- Bump scarb to v2.7.0-rc.1 (#1025)
- Bump scarb to v2.7.0-rc.2 (#1052)
- Bump scarb to v2.7.0-rc.4 (#1064)
- Bump scarb to v2.7.0 (#1065)

### Changed (Breaking)

- Test utilities moved out of the utils module (#1084).
- Test utilities refactored to match the snforge test runner (#1084).

## 0.15.0-rc.0 (2024-07-8)

### Changed

- `Trace`, `Checkpoint`, and `StorageArray` structs made public.

### Changed (Breaking)

- Removed `num_checkpoints` and `checkpoints` from `ERC20VotesABI`.

## 0.14.0 (2024-06-14)

### Changed (Breaking)

- Migrated to the `2023_11` edition (#995):
  - Component implementations annotated with `#[embeddable_as()]` (e.g: `AccessControlComponent::AccessControl`) are not public anymore. Note that the embeddable versions are still public (e.g: `AccessControlComponent::AccessControlImpl`).
  - Implementations that can be compiler-derived from traits are not public anymore (e.g: `DualCaseAccessControlImpl` is not public while `DualCaseAccessControlTrait` is).
  - `Secp256k1PointPartialEq` and `DebugSecp256k1Point` are not public anymore.
  - `account::utils::execute_single_call` is not public anymore.
  - Presets are not public anymore, since they should be copied into projects, and not directly imported.
  - `Trace` and `Checkpoint` structs are not public anymore, since they are intended to be used in `ERC20Votes`, and not as generic utilities.
  - `StorageArray` is not public anymore, since this implementation is specific to `ERC20Votes`, and is not intended as a generic utility, but as a temporary solution until Starknet native implementation arrives.

- Apply underscore pattern to modules (#993):
  - AccessControlComponent
    - `_set_role_admin` function renamed to `set_role_admin`
  - PausableComponent
    - `_pause` function renamed to `pause`
    - `_unpause` function renamed to `unpause`
  - UpgradeableComponent
    - `_upgrade` function renamed to `upgrade`
  - ERC20Component:
    - `_mint` function renamed to `mint`
    - `_burn` function renamed to `burn`
    - `_update` function renamed to `update`
  - ERC721Component:
    - `_safe_transfer` function renamed to `safe_transfer`
    - `_safe_mint` function renamed to `safe_mint`
    - `_mint` function renamed to `mint`
    - `_transfer` function renamed to `transfer`
    - `_burn` function renamed to `burn`
    - `_update` function renamed to `update`
  - ERC1155Component:
    - `set_base_uri` function renamed to `_set_base_uri`

## 0.13.0 (2024-05-20)

### Added

- Sending transactions section in account docs (#981)
- before_update and after_update hooks to ERC721Component (#978)
- before_update and after_update hooks to ERC1155Component (#982)

### Changed (Breaking)

- ERC721Component internal implementation to support transfer, mint, and burn flows going through an `_update` function (#978)
- ERC721Component implementations now require an ERC721HooksTrait implementation in scope (#978)
- ERC1155Component implementations now require an ERC1155HooksTrait implementation in scope (#982)
- AccountComponent, preset, and dispatcher now require a `signature` param in the public-key-setter functions (#989)
- EthAccountComponent, preset, and dispatcher now require a `signature` param in the public-key-setter functions (#990)

## 0.12.0 (2024-04-21)

### Added

- before_update and after_update hooks to ERC20Component (#951)
- INSUFFICIENT_BALANCE and INSUFFICIENT_ALLOWANCE errors to ERC20Component (#951)
- ERC20Votes component (#951)
- Preset interfaces (#964)
- UDC docs (#954)
- Util functions to precompute addresses (#954)

### Changed

- Allow testing utilities to be importable (#963)
- Utilities documentation (#963)
- Parameter name in `tests::utils::drop_events` (`count` -> `n_events`) (#963)
- Presets to include upgradeable functionality (#964)
- ERC20, ERC721, and ERC1155 presets include Ownable functionality (#964)
- EthAccount
  - Expected signature format changed from `(r, s, y)` to `(r, s)` (#940)

## 0.11.0 (2024-03-29)

### Added

- SNIP12 utilities for on-chain typed messages hash generation (#935)
- Nonces component utility (#935)
- Presets Usage guide (#949)
- UDC preset contract (#919)
- ERC1155Component and ERC1155ReceiverComponent mixins (#941)
- ERC721ReceiverComponent documentation (#945)

### Fixed

- ERC721ReceiverComponent mixin embeddable implementation name (#945)

### Removed

- DualCase SRC5 (#882, #952)

## 0.10.0 (2024-03-07)

### Added

- ERC1155 component and preset (#896)
- Mixin implementations in components (#863)
- ERC721Component functions and Storage member
  - `InternalTrait::_set_base_uri` and `InternalTrait::_base_uri` to handle ByteArrays (#857)
  - `ERC721_base_uri` Storage member to store the base URI (#857)

### Changed

- Change unwrap to unwrap_syscall (#901)
- ERC20Component
  - `IERC20::name` and `IERC20::symbol` return ByteArrays instead of felts (#857)
- ERC721Component
  - `IERC721::name`, `IERC721::symbol`, and `IERC721Metadata::token_uri` return ByteArrays instead of felts (#857)
  - `InternalTrait::initializer` accepts an additional `base_uri` ByteArray parameter (#857)
  - IERC721Metadata SRC5 interface ID. This is changed because of the ByteArray integration (#857)

### Removed

- ERC721Component function and Storage member
  - `InternalTrait::_set_token_uri` because individual token URIs are no longer stored (#857)
  - `ERC721_token_uri` Storage member because individual token URIs are no longer stored (#857)

## 0.9.0 (2024-02-08)

### Added

- EthAccount component and preset (#853)
- Ownable two-step functionality (#809)

### Changed

- Bump scarb to v2.4.4 (#853)
- Bump scarb to v2.5.3 (#898)
- OwnershipTransferred event args are indexed (#809)

### Removed

- Non standard increase_allowance and decrease_allowance functions in ERC20 contract (#881)

## 0.8.1 (2024-01-23)

### Added

- Documentation for SRC5 migration (#821)
- Usage docs (#823)
- Utilities documentation (#825)
- Documentation for presets (#832)
- Backwards compatibility notice (#861)
- Add automatic version bump to CI (#862)

### Changed

- Use ComponentState in tests (#836)
- Docsite navbar (#838)
- Account events indexed keys (#853)
- Support higher tx versions in Account (#858)
- Bump scarb to v2.4.1 (#858)
- Add security section to Upgrades docs (#861)
