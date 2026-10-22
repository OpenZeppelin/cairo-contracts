# GitHub Copilot instructions

Read and follow [AGENTS.md](../AGENTS.md), [GUIDELINES.md](../GUIDELINES.md) and
[ARCHITECTURE.md](../ARCHITECTURE.md). Use the setup and verification commands linked from
`AGENTS.md`.

## Critical conventions

- Prefer numeric literals without type suffixes when the compiler can infer the type.
- Prefix component storage members with the component name (for example `ERC20_balances`).
  Preserve deployed field names and types; assess storage compatibility before changing them.

For reviews, follow the [code-quality procedure](../.claude/skills/code-quality/SKILL.md).
Do not present undocumented preferences as repository rules.
