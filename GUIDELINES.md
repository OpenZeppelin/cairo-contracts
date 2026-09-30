# Guidelines

Coding and testing conventions for OpenZeppelin Contracts for Cairo. Read
[ARCHITECTURE.md](ARCHITECTURE.md) for the package boundaries and design constraints, and
[CONTRIBUTING.md](CONTRIBUTING.md) for setup, verification commands and contribution process.

## Naming and layout

- Use `snake_case` for Cairo files, ordinary modules, functions, parameters and local variables.
  Use `PascalCase` for types, traits, component modules and implementations, and
  `SCREAMING_SNAKE_CASE` for constants.
- Name reusable components with a `Component` suffix, interfaces with an `I` prefix, and
  interface implementations with an `Impl` suffix. Keep the existing names of standard APIs
  and compatibility entry points, including their camelCase aliases.
- Follow the surrounding module's organization. Component files generally contain imports,
  constants, storage, events, errors, configuration and hooks, external implementations,
  compatibility implementations, mixins, and internal implementations. Use the existing
  section comments when extending one of these files.
- Keep shared ABI traits in `packages/interfaces`, deployable presets in `packages/presets`,
  and reusable test mocks in `packages/test_common`. Export public items through the relevant
  module and package entry points.
- Preserve the SPDX license identifier and project/version header in source files that use
  them. Use the corresponding neighboring source file as the header model for new files.

## Imports and types

- Import dependencies explicitly and let Scarb's formatter sort module-level items. Use
  `crate::` for paths within a package and the package name for cross-package dependencies.
- Use aliases to disambiguate traits, such as a component's `InternalTrait`, when composing
  multiple components.
- Use semantic Starknet types such as `ContractAddress` and `ClassHash` for their respective
  values, and the integer type required by the interface for amounts and counters.
- Prefer numeric literals without explicit type suffixes when the compiler can infer the
  type; keep suffixes only when inference fails or an explicit type is required for
  arithmetic/disambiguation.
- Use snapshot receivers for read-only operations and `ref self` for state mutation. Match the
  receiver and parameter order of the interface being implemented.

## Functions, events and errors

- Put reusable state transitions in the component's internal implementation. Delegate from
  external implementations and compatibility aliases so their validation and behavior stay
  consistent.
- Keep component error constants in its `Errors` module and follow its existing message
  format. Assert the documented preconditions with the corresponding error; do not silently
  discard failed syscall or dispatcher results.
- Make authorization explicit at externally exposed entry points. When an internal helper
  intentionally has no access restriction, document that fact for callers.
- Preserve documented event ordering, keys and data. Cover changes to observable events and
  error messages with tests and describe user-facing changes in the changelog.
- Compose extensions through the component's hooks and configuration traits. Delegate to the
  existing transition helpers rather than bypassing their hooks with direct storage writes.

## Testing

Tests must be clear enough for reviewers to assess the behavior they protect. Add relevant
unit tests for new features and regressions; test successful paths, authorization failures,
invalid input, boundary values, state transitions and emitted events as applicable.

- Keep Cairo tests under the package's `src/tests` tree, in `test_*.cairo` modules with `test_`
  function names. Match the organization of the module under test.
- Use `openzeppelin_testing` for shared deployment, constants, signing and event helpers, and
  `openzeppelin_test_common` for repository-specific mocks and fixtures.
- Use `component_state_for_testing` for isolated component behavior and deployed mocks or
  presets for contract composition and ABI behavior. Target caller and other cheatcodes at
  the contract under test so the test's authority assumptions are explicit.
- Assert expected panic data with `#[should_panic(expected: ...)]` and check event keys/data,
  not only that a transaction succeeded. Exercise both snake_case and supported camelCase
  entry points when changing their shared behavior.
- Keep fuzz tests behind the package's `fuzzing` feature where used. Use boundary cases in
  addition to randomized inputs.
- Keep Rust macro tests in `packages/macros/src/tests`. Cover accepted expansions and rejected
  inputs when changing macro parsing or diagnostics.
- For Falcon arithmetic changes, retain the exhaustive basis-vector test and run the generator,
  fixture checks and release-profile tests in
  [CONTRIBUTING.md](CONTRIBUTING.md#falcon-verification-sources). Generated files are reproduced
  from their generator, not edited by hand.

The coverage gate is defined in [CONTRIBUTING.md](CONTRIBUTING.md#code-quality-standards).
For features whose behavior depends on network execution, follow the
[integration-test process](CONTRIBUTING.md#integration-tests).

## Formatting and linting

Use Scarb's workspace formatter with the settings in [Scarb.toml](Scarb.toml), including
`sort-module-level-items = true`. Rust macros use `cargo fmt` and `cargo clippy`.
Markdown follows [.markdownlint.jsonc](.markdownlint.jsonc); line length is disabled to allow
paragraphs without forced wrapping. Keep lint suppressions narrow and explain their purpose.
Run the commands in [CONTRIBUTING.md](CONTRIBUTING.md#verification).

## Documentation

Use `///` comments for public Cairo APIs and explain their purpose, preconditions, authorization,
return values, failure conditions and emitted events where relevant. Document extension hooks
and configuration requirements so integrators can compose components correctly.

Keep package READMEs as catalogs of their public modules. Maintain user guides and API reference
pages in the [OpenZeppelin Documentation repository](https://github.com/OpenZeppelin/docs/tree/main/content/contracts-cairo).
Follow [CONTRIBUTING.md](CONTRIBUTING.md#documentation) for documentation updates, generated
testing-package documentation and preset class hashes.
