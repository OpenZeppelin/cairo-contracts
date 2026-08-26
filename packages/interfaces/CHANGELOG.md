<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 2.2.0 (2026-08-26)

### Added

- `IERC20Wrapper` and `IERC20WrapperABI` interfaces (#1617)
- `IERC721Wrapper` and `IERC721ReceiverMut` interfaces (#1625)
- `IERC1155Supply` interface (#1632)
- ERC-6909 interfaces, ABI trait, and interface IDs (#1594)
- `IERC6909MetadataAdmin` and `IERC6909ContentUriAdmin` interfaces and their
  `ERC6909ABI` methods (#1676)
- `IERC3156FlashLender` and `IERC3156FlashBorrower` interfaces (#1608)

### Changed

- Updated the Cairo and Scarb requirement to 2.18.0

## 2.1.0 (2025-12-11)

### Added

- Moved interfaces, ABIs and dispatchers into `openzeppelin_interfaces` (#1463)
  - Some structs and types that were defined inside interface files were also moved

## 2.1.0-alpha.0 (2025-09-17)

### Added

- Moved interfaces, ABIs and dispatchers into `openzeppelin_interfaces` (#1463)
  - Some structs and types that were defined inside interface files were also moved
