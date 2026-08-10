## Corelib Imports

Provides the gated Cairo corelib re-exports required by OpenZeppelin packages. The `2023_10`
edition exposes these APIs under Cairo 2.18.0; they are unavailable to a `2024_07` package in that
compiler version.

This compiler-compatibility package contains only re-exports. Its API is internal to the workspace
and may change with Cairo compiler upgrades.
