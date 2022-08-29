# Releasing

Releasing checklist:

(1) Write a changelog.

(2) Checkout the branch to be released. This should be `main` except in the event of a hotfix. For hotfixes, checkout the latest release branch.

(3) Create a tag for the release.

```sh
git tag v0.2.0
```

(4) Push the tag to the main repository, [triggering the CI and release process](https://github.com/OpenZeppelin/cairo-contracts/blob/b27101eb826fae73f49751fa384c2a0ff3377af2/.github/workflows/python-app.yml#L60).

```sh
git push origin v0.2.0
```

Note that the CI automatically:

- Updates the SPDX identifiers and antora.yml versions with the pushed tag
- Creates a release branch and adds a tag to it. This can be useful if we need to push a hot fix on top of an existing release in the case of a bug.

(5) Finally, go to the repo's [releases page](https://github.com/OpenZeppelin/cairo-contracts/releases/) and [create a new one](https://github.com/OpenZeppelin/cairo-contracts/releases/new) with the new tag and the base branch as target (which should be `main` except in the event of a hotfix).
