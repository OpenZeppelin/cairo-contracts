# Releasing

This guide is for maintainers with repository write access and Scarb registry publishing access.
Follow the [commit and review conventions](CONTRIBUTING.md#commit-and-pr-conventions).
The examples use `upstream` for the OpenZeppelin remote.

## Release branches and versions

Library releases use `release-vX.Y.Z` branches and `vX.Y.Z` final tags. Release candidates are
GitHub prerelease tags on the same release branch, such as `v4.0.0-rc.0` and `v4.0.0-rc.1`.
Their manifests retain the final version (`4.0.0` in this example); RCs are not published to
scarbs.xyz.

The [preparation workflow](.github/workflows/prepare-release.yml) runs when a `release-v`
branch is created. It derives the package version from the branch suffix and commits version
replacements. Later pushes do not rerun it. Tags, GitHub releases and registry publication are
separate maintainer steps.

Most packages inherit the workspace version; `openzeppelin_interfaces`, `openzeppelin_utils`
and `openzeppelin_testing` have independent versions. Review their manifests and dependency
requirements separately. The workflow excludes the testing package, audits, changelog and this
guide, and replaces only the exact workspace-version string elsewhere.

## Prepare a release

1. Create the branch from the reviewed base, substituting the release numbers below.
   For a normal release:

   ```sh
   git fetch upstream
   git switch -c release-vX.Y.Z upstream/main
   ```

   For a hotfix, start from the release line being fixed:

   ```sh
   git fetch upstream
   git switch -c release-vX.Y.Z upstream/release-vA.B.C
   ```

   Push the branch to trigger preparation:

   ```sh
   git push -u upstream release-vX.Y.Z
   ```

2. Fetch the workflow's version-bump commit with `git pull --ff-only`. Review the generated
   diff, including manifests, dependency requirements, macro versions and source headers.

3. Assemble a dated [changelog](CHANGELOG.md) entry from `Unreleased`, preserving change
   categories, breaking-change notices and PR references. Leave `Unreleased` available for
   subsequent work. The final release notes must include all changes since the previous stable
   release, including fixes made during the RC period.

4. Open a PR against `main` or the maintained release line for a hotfix. Review compatibility
   and audit scope, and run the [verification commands](CONTRIBUTING.md#verification).
   Keep the release branch on the reviewed changes intended for publication.

## Release candidates

From the reviewed release branch, tag a candidate and push it:

```sh
git tag vX.Y.Z-rc.0
git push upstream vX.Y.Z-rc.0
```

Create a [GitHub prerelease](https://github.com/OpenZeppelin/cairo-contracts/releases/new) for
the tag. Keep the release's manifest and dependency versions unchanged, and publish no registry packages.
For another candidate, incorporate reviewed fixes on the same release branch and create a
new tag such as `vX.Y.Z-rc.1`.

## Final release and package publication

Review the candidate-to-final diff, finalize the changelog and rerun the relevant checks.
Tag the reviewed final commit and push it:

```sh
git tag vX.Y.Z
git push upstream vX.Y.Z
```

RC manifests already use the final version. Published tags and package versions must not be
moved or reused for different contents.

Registry publication is manual. From the clean final-release checkout, replace `PACKAGE`
with a package included in the release:

```sh
scarb package --list -p PACKAGE
scarb package -p PACKAGE
scarb publish -p PACKAGE
```

Use the authorized registry account and keep package verification enabled. Publish dependencies
before their dependents, checking independently versioned packages separately. Publish only
selected distribution packages; workspace membership alone does not require publication.
Confirm each version is available, then build a fresh consumer using registry dependencies.
See [Scarb's publishing guide](https://docs.swmansion.com/scarb/docs/registries/publishing.html).

Create the final [GitHub release](https://github.com/OpenZeppelin/cairo-contracts/releases/new)
from the tag, with the changelog, compatibility notes and applicable audit links.
Forward-port release fixes and the final changelog to `main` when needed.

## Documentation checklist

- Update the [documentation repository](https://github.com/OpenZeppelin/docs/tree/main/content/contracts-cairo)
  for the release, including [preset class hashes](CONTRIBUTING.md#preset-class-hashes).
- Check installation examples in `README.md` against published package versions and the
  release's toolchain. Check versioned documentation URLs in `README.md`, `llms.txt` and
  `ARCHITECTURE.md`; major-version URLs and toolchain numbers are not updated by version
  replacement alone.
- Update consumer links in `llms.txt` to the released tag and verify every target exists.
  Testing-package links use their own release commit. Keep the audit index and contributor
  instructions current; newly added guides may be absent from older release tags.
- Index published audit reports with their exact reviewed commits in [audits/README.md](audits/README.md).

## Testing package releases

`openzeppelin_testing` has its own version and [changelog](packages/testing/CHANGELOG.md).
Create an `openzeppelin_testing-vX.Y.Z` branch from the intended base. The
[testing preparation workflow](.github/workflows/prepare-testing-release.yml) updates its
version, runs `scarb doc`, and moves `target/doc/openzeppelin_testing/src` into
`packages/testing/docs` before committing the result.

Review the generated diff, update the package changelog and test with the pinned Foundry
version. Publish `openzeppelin_testing` from the reviewed release commit and merge the release
PR. The existing `openzeppelin_testing-vX.Y.Z` refs are branches; this process creates no
matching tags or tagged GitHub releases.

Pin testing catalog and API links in `llms.txt` to the commit containing that release's code
and generated documentation. Verify its independently published version, documentation links
and registry dependency.
