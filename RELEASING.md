# Releasing

(1) Checkout the branch to be released. This will usually be `main` except in the event of a hotfix. For hotfixes, checkout the release branch you want to fix.

(2) Create and push a new release branch.

```sh
git checkout -b release-v0.8.0
git push release-v0.8.0
```

(3) Create a tag for the release and push it to the main repository.

```sh
git tag v0.8.0
git push origin v0.5.1
```

(4) Finally, go to the repo's [releases page](https://github.com/OpenZeppelin/cairo-contracts/releases/) and [create a new one](https://github.com/OpenZeppelin/cairo-contracts/releases/new) with the new tag and the base branch as target (`main` except in the event of a hotfix).
Make sure to write a detailed release description and a short changelog.
