# Releasing

This guide is for maintainers with write access to the repository and publishing access to the
Scarb registry. Contribution, signing and review conventions are in
[CONTRIBUTING.md](CONTRIBUTING.md#commit-and-pr-conventions).

## Release branches and versions

Use `release-vX.Y.Z` branches for library releases and `vX.Y.Z` tags for final releases.
Prerelease tags include the full version suffix, for example `v4.0.0-rc.0` and `v4.0.0-rc.1`.
Start a release from the reviewed `main` commit; start a hotfix from the relevant release branch.
The examples below use `upstream` for the OpenZeppelin remote and `origin` for a contributor's
fork, as in [CONTRIBUTING.md](CONTRIBUTING.md#a-typical-workflow).

The [release preparation workflow](.github/workflows/prepare-release.yml) runs when a
`release-v` branch is created. It derives the new version from the branch suffix and commits
version replacements. It does **not** run on later pushes, create tags, publish packages or
create a GitHub release. If a branch includes a prerelease suffix, that suffix is part of the
version it writes.

Review the generated diff. Most packages inherit `workspace.package.version`, but
`openzeppelin_interfaces`, `openzeppelin_utils` and `openzeppelin_testing` have independent
versions. Verify their manifests and every dependent version requirement separately. The
workflow excludes the testing package, audit reports, changelog and this guide. It performs
text replacement, so a successful run is not a substitute for reviewing the resulting metadata.

## Prepare a release

1. Fetch the OpenZeppelin remote and check out the intended base. Create the release branch
   from that commit, substituting the release number in these examples:

   ```sh
   git fetch upstream
   git switch -c release-vX.Y.Z upstream/main
   git push -u upstream release-vX.Y.Z
   ```

2. Fetch the preparation workflow's version-bump commit and update the local branch with
   `git pull --ff-only`. For a release candidate on an existing release branch, explicitly
   update the manifests, internal dependency requirements, Rust macro version and source
   headers to the candidate version; branch creation automation does not run again.

3. Assemble a dated release entry in [CHANGELOG.md](CHANGELOG.md) from `Unreleased`, preserving
   change categories, breaking-change notices and PR references. Leave `Unreleased` available
   for subsequent changes. Include changes from earlier candidates in the final release's
   notes so stable-version users can see the full change set.

4. Open a PR for the release changes against `main` (or the maintained release line for a
   hotfix). Review the version changes, changelog, compatibility implications and audit scope.
   Run the [verification commands](CONTRIBUTING.md#verification), including release-profile
   checks for affected code. Merge the reviewed changes and ensure the release branch
   contains the exact changes intended for the tag. Keep unrelated development off that branch.

5. From a clean checkout of the reviewed release commit, create and push the corresponding tag:

   ```sh
   git tag -s vX.Y.Z -m "Release vX.Y.Z"
   git push upstream vX.Y.Z
   ```

   For a candidate, use the complete candidate version in both the tag name and annotation.
   Verify the commit before tagging; published tags and package versions must not be moved
   or reused for different contents.

## Publish packages

Package publication is a separate maintainer step. The workflows in this repository prepare
versions and test code; neither pushing a tag nor creating a GitHub release uploads packages
to the Scarb registry.

From the tagged, clean checkout, select a package name in place of `PACKAGE` and run:

```sh
scarb package --list -p PACKAGE
scarb package -p PACKAGE
scarb publish -p PACKAGE
```

Use the registry account authorized for that package. Scarb verifies package contents by
building them; keep that verification enabled.

Publish only packages included in the release, with dependencies available in the registry
before their dependents. Use the versioned manifests to determine the dependency order and
which independently versioned packages need publication. Publish the umbrella `openzeppelin`
package after its dependencies. Repository test support such as `openzeppelin_test_common`
is not a downstream contract dependency; do not blindly publish every workspace member.

Confirm the versions are available in the registry, then build a fresh consumer project using
the released registry dependencies. This checks the published packages rather than local
workspace paths. See [Scarb's publishing guide](https://docs.swmansion.com/scarb/docs/registries/publishing.html)
for registry setup and package verification.

## Release candidates and final promotion

Publish candidates as distinct prerelease versions such as `X.Y.Z-rc.0`, marking the matching
GitHub release as a prerelease. Incorporate fixes through reviewed PRs on the release line and
publish each subsequent candidate under a new version.

For final promotion, review the candidate-to-final diff, remove the prerelease suffix from the
release's package versions and dependency requirements, finalize the changelog and rerun the
release checks. Create a fresh final tag and publish the final package versions from that
commit. Changing a GitHub prerelease flag does not change package contents or versions.

## GitHub release and documentation

Create the [GitHub release](https://github.com/OpenZeppelin/cairo-contracts/releases/new) from
the published tag, with a summary, user-facing changelog, compatibility notes and audit links
where available. Select prerelease status for candidates.

Update the [OpenZeppelin Documentation repository](https://github.com/OpenZeppelin/docs/tree/main/content/contracts-cairo)
for the released version, including the preset class hashes generated with the release's
compiler. See [CONTRIBUTING.md](CONTRIBUTING.md#preset-class-hashes) for that procedure.
Add any published audit reports and their exact reviewed commits to [the audit index](audits/README.md).
Forward-port release fixes and the final changelog to `main` when they landed only on the
release branch.

## Testing package releases

`openzeppelin_testing` has its own version and [changelog](packages/testing/CHANGELOG.md).
Create an `openzeppelin_testing-vX.Y.Z` branch from the intended base. The
[testing release workflow](.github/workflows/prepare-testing-release.yml) updates the testing
package's version and refreshes `packages/testing/docs` using `scarb doc`.

Review that generated diff, update the package changelog and test with the pinned Foundry
version. After review, tag the release as `openzeppelin_testing-vX.Y.Z` and publish only
`openzeppelin_testing` from that tagged checkout. Create a GitHub release for the tag and
verify its registry dependency and generated documentation links.
