<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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

### Changed

- Bump scarb to v2.6.3 (#946)

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
