<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- EthAccount component and preset (#853)

### Changed

- Bump scarb to v2.4.4 (#853)
  
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