# Releasing

Releasing checklist

(1) Write a changelog.

(2) In the [Bump version workflow](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/version.yml), run the workflow dispatch with the appropriate bump type (patch, minor, major).
The listed branch should be `main` except in the event of a hotfix. For hotfixes, select the latest release branch and set the bump type to `override`.

(3) Go to the repo's [releases page](https://github.com/OpenZeppelin/cairo-contracts/releases/) and [create a new one](https://github.com/OpenZeppelin/cairo-contracts/releases/new) with the new tag and the base branch as target (which should be `main` except in the event of a hotfix).
