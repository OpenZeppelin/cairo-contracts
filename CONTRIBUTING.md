# Contributing to OpenZeppelin Contracts for Cairo

Contributions are welcome. Read this guide and the [Code of Conduct](CODE_OF_CONDUCT.md) before
starting work. Ask for help in an issue when you need clarification.

## Opening an issue

Before starting development, please
[create an issue](https://github.com/OpenZeppelin/cairo-contracts/issues/new) to open the
discussion, validate that the change is wanted, and coordinate overall implementation details.

**Security vulnerabilities are the exception.** Do not describe a potential vulnerability in a
public issue or pull request. Report it privately as described in [`SECURITY.md`](SECURITY.md)
and wait for the maintainers before doing anything public.

## Creating Pull Requests (PRs)

Fork the repository and submit a pull request from your fork.

## Code quality standards

Read [GUIDELINES.md](GUIDELINES.md) and [ARCHITECTURE.md](ARCHITECTURE.md) before opening a PR.

- **Test coverage**: pass the checks configured in [codecov.yml](codecov.yml). Project coverage
  uses the PR base as its target with a 4 percentage-point tolerance. Patch coverage targets
  80% with the same tolerance.
- **Formatting and linting**: all code must pass the formatter and linting with the
  commands in [Verification](#verification).
- **Conventions**: follow [`GUIDELINES.md`](GUIDELINES.md).
- **Documentation**: add inline documentation for every public API, formatted per
  [`GUIDELINES.md`](GUIDELINES.md).

## Commit and PR conventions

- **Sign every commit.** Configure commit signing before your first contribution; unsigned
  commits will not be merged.
- Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for commit
  messages and PR titles: `type(scope): summary`, e.g. `fix(vesting): reject zero-duration schedules`.
- **Never add a `Co-Authored-By` trailer for an AI assistant.** Add one only for a human
  co-author — you are accountable for everything you submit under your own name, whatever
  tools helped produce it.
- Keep the summary short and imperative, and explain the *why* in the body when it is not
  obvious from the diff.
- Link the issue in the PR description: `Fixes #123` / `Resolves #123` closes it on merge and
  belongs only on a PR that resolves it completely; for partial work a plain `#123` reference is
  enough. Closing keywords act only on PRs targeting the default branch.
- When you make a user-facing change, record it in [`CHANGELOG.md`](CHANGELOG.md) under
  `## Unreleased`, grouped by change type (`### Added` / `Changed` / `Fixed` / ...), following
  [Keep a Changelog](https://keepachangelog.com/), and reference the PR number.

## AI-assisted contributions

AI coding assistants are welcome; see [AGENTS.md](AGENTS.md) for setup. You are responsible for
everything you submit. Read, understand and test it before opening a PR.

Before requesting review, run the relevant tests, formatter and linter, follow the
[code-quality procedure](.claude/skills/code-quality/SKILL.md), and address the findings.

We may close low-effort AI output without further explanation.

## A typical workflow

1. Once, after cloning your fork, add the main repository as `upstream`:

   ```sh
   cd cairo-contracts
   git remote add upstream https://github.com/OpenZeppelin/cairo-contracts.git
   ```

2. With a clean working tree, branch from the current `upstream/main`:

   ```sh
   git fetch upstream
   git checkout -b fix/some-bug-short-description-123 upstream/main
   ```

   The issue number in the branch name (ex: `fix/typos-in-docs-123`) is for readability only;
   the PR is linked to the issue through its description (step 5).

3. Make your changes, add your files and update documentation. Run the tests, the formatter
   and the linter locally and make sure they pass. For external PRs, the checks on GitHub run
   once a maintainer approves them.

   Follow [Development setup](#development-setup) and [Verification](#verification).

4. Commit (signed) and push to your fork.

   ```sh
   git add path/to/changed-file
   git commit -S -m "fix: some bug short description #123"
   git push origin fix/some-bug-short-description-123
   ```

5. Go to [OpenZeppelin/cairo-contracts](https://github.com/OpenZeppelin/cairo-contracts) in your web browser
   and issue a new pull request. Link the issue in the description as set out in *Commit and
   PR conventions*, and make sure all PR checks pass before requesting a review.

6. Address maintainer feedback before merging.

## Development setup

Install Scarb and Starknet Foundry using the versions in [Scarb.toml](Scarb.toml):
`workspace.package.scarb-version` pins Scarb (and its bundled Cairo compiler), and
`workspace.dependencies.snforge_std` pins the matching `snforge` version. The manifests also
specify each package's Cairo edition. Rust and Cargo are needed for `packages/macros`; Node.js
and npm are needed for Markdown linting; Python 3 is needed for the repository scripts.

```sh
scarb --version
snforge --version
scarb build --workspace
```

For coverage, install [cairo-coverage](https://github.com/software-mansion/cairo-coverage).
The Falcon resource checker also requires Universal Sierra Compiler on `PATH`.

## Verification

Run commands from the repository root. These commands mirror
[the Cairo workflow](.github/workflows/test.yml):

```sh
scarb fmt --check --workspace
snforge test --workspace --features fuzzing --fuzzer-runs 200 --skip falcon_512
snforge test --workspace --coverage
```

Run the [Falcon checks](#falcon-verification-sources) as well when modifying the account,
preset or generated arithmetic paths. Coverage alone does not test the production NTT path;
see [Verification boundaries](ARCHITECTURE.md#verification-boundaries).

For a focused test run, select a package and optionally a test-name filter:

```sh
snforge test -p openzeppelin_token test_transfer
```

For Markdown changes, run the same lint scope as CI:

```sh
npx --yes markdownlint-cli2@0.13.0 '*.md' 'audits/README.md' '.github/copilot-instructions.md' '.claude/skills/code-quality/SKILL.md' '#PULL_REQUEST_TEMPLATE.md'
```

For Rust macro changes, also run [the macro workflow](.github/workflows/test-macros.yml) commands:

```sh
cargo fmt --manifest-path packages/macros/Cargo.toml --all --check
cargo clippy --manifest-path packages/macros/Cargo.toml --all --all-targets
cargo test --manifest-path packages/macros/Cargo.toml
```

## Tests

Follow the [testing guidelines](GUIDELINES.md#testing) and the
[coverage requirements](#code-quality-standards).

## Documentation

Documentation for Contracts for Cairo is maintained in the [OpenZeppelin Documentation repository](https://github.com/OpenZeppelin/docs/tree/main/content/contracts-cairo). When a contribution changes documented behavior, update the corresponding documentation in that repository.

### Preset class hashes

To generate the JavaScript constants used by the preset documentation, make sure `scarb` and `starkli` are installed and configured, then run:

```bash
python3 scripts/generate_class_hashes.py
```

The script builds the `openzeppelin_presets` release artifacts and prints the `CLASS_HASH_SCARB_VERSION` and `CLASS_HASHES` constants for every current preset. Copy them into the corresponding `content/contracts-cairo/<version>/utils/constants.js` file in the documentation repository and update the preset table when its entries change. Pass `--no-build` to reuse existing release artifacts.

### Testing package API documentation

Regenerate the testing package reference with `scarb doc -p openzeppelin_testing`. Its release
workflow refreshes `packages/testing/docs`; see [RELEASING.md](RELEASING.md#testing-package-releases).

## Falcon verification sources

The Falcon root tables, bit-reversal table, and unrolled production transform are derived and
checked by the NTT generator. Regenerate them from the repository root with the workspace's
Scarb version:

```sh
python3 scripts/falcon_512/generate_ntt.py --write
git diff -- packages/account/src/falcon_512/ntt
```

Follow the [Falcon testing conventions](GUIDELINES.md#testing) when changing generated arithmetic.

`scripts/falcon_512/check_fixtures.py` provides reference encoders for decoded Falcon keys and
signatures and checks all committed vectors using Python's SHAKE-256 and schoolbook polynomial
multiplication. The vectors retain their `tprest/falcon.py` provenance. Their original signing
seeds and secret keys are not recorded with the fixtures; this check reproduces the encoding and validates the
signatures, not the signer's randomness.

```sh
python3 scripts/falcon_512/check_fixtures.py
python3 -m unittest discover -s scripts/falcon_512 -p 'test_*.py'
scarb --release build -p openzeppelin_presets
python3 scripts/falcon_512/check_resources.py
```

Run the production verifier, preset and exhaustive basis-vector tests:

```sh
snforge test -p openzeppelin_account --release --features falcon_fast_tests falcon_512 --skip every_basis_vector --max-n-steps 5000000
snforge test -p openzeppelin_presets --release --features falcon_presets_tests falcon_512 --max-n-steps 5000000
snforge test -p openzeppelin_account --release --features falcon_fast_tests every_basis_vector --max-n-steps 100000000
```

The generator checks all 512 basis vectors, inverse transforms, pointwise products and integer
bounds. The fixture checker validates committed signatures and their encodings; it does not
reproduce the original signing randomness. See [ARCHITECTURE.md](ARCHITECTURE.md#verification-boundaries)
for compiler-profile, coverage and network limitations.

## Integration tests

For new features that depend on network behavior, test against a public testnet and share a
reviewable transaction in the PR. Prefer a verified contract whose execution the reviewer can
trace and reproduce. Local execution does not exercise every network constraint.

## Getting help

Ask questions in an [issue](https://github.com/OpenZeppelin/cairo-contracts/issues), or find a
[good first issue](https://github.com/OpenZeppelin/cairo-contracts/labels/good%20first%20issue).
