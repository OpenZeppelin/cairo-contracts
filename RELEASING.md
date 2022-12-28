# Releasing

Releasing checklist:

(1) Write a changelog.

(2) Run version bump script with the new version as an argument and open a PR.

```sh
python scripts/update_version.py v0.5.1
```

(3) Create and push a release branch.

```txt
git checkout -b release-v0.5.1
git push release-v0.5.1
```

(4) Checkout the branch to be released. This should be `main` except in the event of a hotfix. For hotfixes, checkout the latest release branch.

(5) Create a tag for the release.

```sh
git tag v0.5.1
```

(6) Push the tag to the main repository, [triggering the CI and release process](https://github.com/OpenZeppelin/cairo-contracts/blob/b27101eb826fae73f49751fa384c2a0ff3377af2/.github/workflows/python-app.yml#L60).

```sh
git push origin v0.5.1
```

(7) Finally, go to the repo's [releases page](https://github.com/OpenZeppelin/cairo-contracts/releases/) and [create a new one](https://github.com/OpenZeppelin/cairo-contracts/releases/new) with the new tag and the base branch as target (which should be `main` except in the event of a hotfix).
