# Releasing

(1) Checkout the branch to be released. This will usually be `main` except in the event of a hotfix. For hotfixes, checkout the release branch you want to fix.

(2) Create a new release branch.

```sh
git checkout -b release-v0.8.0
```

(3) Search and replace the current release version with the one to be released (e.g. `0.7.0` to `0.8.0`, or `0.8.0-beta.0` to `0.8.0-beta.1`).

(4) Create the release entry in [the changelog](CHANGELOG.md) with the contents of the _Unreleased_ section, which should be left empty.

(5) Push and open a PR targeting `main` to carefully review the release changes.

```sh
git push release-v0.8.0
```

(6) Once merged, create a tag on the release branch and push it to the main repository.

```sh
git tag v0.8.0
git push origin v0.8.0
```

(7) Finally, go to the repo's [releases page](https://github.com/OpenZeppelin/cairo-contracts/releases/) and [create a new one](https://github.com/OpenZeppelin/cairo-contracts/releases/new) with the new tag and the base branch as target (`main` except in the event of a hotfix).
Make sure to write a detailed release description and a short changelog.
