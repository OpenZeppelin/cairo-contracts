---
name: code-quality
description: Review or improve code, documentation and configuration against this repository's conventions and design constraints. Use for code-quality, style or consistency reviews.
---

# Code quality

Run repository commands from the repository root.

1. Review the requested scope. Otherwise, compare against the PR base, including staged,
   unstaged and untracked changes. For stacked PRs, use the immediate parent branch.
   Without a PR, identify and state the base from local context. Exclude generated files only
   as documented by the repository. If nothing is in scope, say so.
2. Read the relevant [guidelines](../../../GUIDELINES.md),
   [architecture](../../../ARCHITECTURE.md) and [contribution guide](../../../CONTRIBUTING.md).
   Use the setup and verification commands in the contribution guide.
3. Report findings with file, line and proposed correction. Cite the relevant convention or
   evidence of a defect. Identify documentation gaps rather than inventing rules.
4. For fix requests, apply supported corrections and run the relevant checks. For review-only
   requests, report findings without editing. State checks that could not run and why.
