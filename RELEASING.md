# Releasing

Releasing checklist:

(1) Write a changelog.

(2) Make sure to update SPDX license identifiers. For example:

```cairo
# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (account/Account.cairo)
```

to

```cairo
# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (account/Account.cairo)
```

(3) Create a release branch and add a tag to it. This branch can be useful if we need to push a hot fix on top of an existing release in the case of a bug.

```sh
git checkout -b release-0.2.0
git tag v0.2.0
```

(4) Push the tag to the main repository, [triggering the CI and release process](https://github.com/OpenZeppelin/cairo-contracts/blob/b27101eb826fae73f49751fa384c2a0ff3377af2/.github/workflows/python-app.yml#L60).

```sh
git push origin v0.2.0
```
