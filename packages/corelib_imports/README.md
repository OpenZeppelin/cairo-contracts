## Corelib Imports

Provides the gated Cairo corelib re-exports required by OpenZeppelin packages. The `2023_10`
edition exposes these APIs under Cairo 2.18.0; they are unavailable to a `2024_07` package in that
compiler version.

This compiler-compatibility package contains only re-exports. Its API is internal to the workspace
and depends on internal, unstable compiler APIs, including the `bounded-int-utils` feature.
It is not a stable extension API for applications. Cairo upgrades can change or remove these
imports and require checking the dependent contracts' correctness, size, and execution cost.
