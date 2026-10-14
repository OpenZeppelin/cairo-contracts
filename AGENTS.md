# Agent Guide

Read the following guides before editing or reviewing files:

- [GUIDELINES.md](GUIDELINES.md): coding and testing conventions.
- [ARCHITECTURE.md](ARCHITECTURE.md): package layout and design constraints.
- [CONTRIBUTING.md](CONTRIBUTING.md): contribution process, coverage, commit and PR conventions.

## Critical conventions

- Prefer numeric literals without type suffixes when the compiler can infer the type.
- Prefix component storage members with the component name (for example `ERC20_balances`).
  Preserve deployed field names and types; assess storage compatibility before changing them.

## Build, test and review

Follow [Development setup](CONTRIBUTING.md#development-setup) and
[Verification](CONTRIBUTING.md#verification).

For code-quality reviews, follow [this procedure](.claude/skills/code-quality/SKILL.md),
available as `/code-quality` in Claude Code.

## Using the library

Use [llms.txt](llms.txt) to find packages, examples, API references and audits.
