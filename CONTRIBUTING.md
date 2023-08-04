# Contributing to OpenZeppelin Contracts for Cairo

We really appreciate and value contributions to OpenZeppelin Contracts for Cairo. Please take 5' to review the items listed below to make sure that your contributions are merged as soon as possible.

## Contribution guidelines

Before starting development, please [create an issue](https://github.com/OpenZeppelin/cairo-contracts/issues/new/choose) to open the discussion, validate that the PR is wanted, and coordinate overall implementation details.

Also, consider that snake case is used for Cairo development in general due to its strong Python bias.
This project follows our [Extensibility pattern](https://docs.openzeppelin.com/contracts-cairo/extensibility), camelCasing all exposed function names and their parameters:

```cairo
@external
func exposedFunc(paramOne, paramTwo){
}
```

All internal and otherwise unexposed functions should resort to snake_case:

```cairo
func internal_func(param_one, param_two){
}
```

Compare our preset contracts with the libraries from which they're derived such as the [ERC20 preset](src/token/erc20/presets/ERC20.cairo) and [ERC20 library](src/token/erc20/presets/ERC20.cairo) for full examples.
See [Function names and coding style](https://docs.openzeppelin.com/contracts-cairo/0.4.0/extensibility#function_names_and_coding_style) for more information.

And make sure to always include tests and documentation for the new developments. Please consider the following conventions:

- Naming
  - Libraries should be named `library.cairo`, e.g. `erc20/library.cairo`
  - Contracts should be PascalCased i.e. `MyContract.cairo`
  - Interfaces should be prefixed with an `I`, as in `IAccount.cairo`
  - Test modules should begin with `test_` followed by the contract name i.e. `test_MyContract.py`

- Structure
  - Libraries should cede their names to their parent directory and are named `library.cairo` instead
  - Interfaces should be alongside the library that the interface defines
  - Preset contracts should be within a `presets` directory of the library to which they are a preset
  - Here are example paths:
    - `openzeppelin.token.erc20.library`
    - `openzeppelin.token.erc20.IERC20`
    - `openzeppelin.token.erc20.presets.ERC20Mintable`
  - And a visual guide:

```python
    openzeppelin
          └──token
               └── erc20
                     ├── library.cairo
                     ├── IERC20.cairo
                     └── presets
                            └── ERC20Mintable.cairo
```

- Preset contract testing
  - Though, inheritance is not possible in Cairo, this repo utilizes inheritance for testing. This proves useful for testing multiple contracts that stem from the same base library. For example, the preset contracts [ERC20Mintable](src/token/erc20/presets/ERC20Mintable.cairo) and [ERC20Burnable](src/token/erc20/presets/ERC20Burnable.cairo) both share the base ERC20 functionality. To reduce code repetition, we follow these guidelines:
    - `BaseSuites`
      - module names are not prefixed with `test_`
      - set base tests inside a class
      - class name should not be prefixed with `Test`; otherwise, these tests run twice

    - test modules
      - define the base fixture (`contract_factory`) and any other fixtures not used in the base suite i.e. `erc721_minted`
      - define the test class and inherit the base class i.e. `class TestERC20(OwnableBase)`
      - add tests specific to the preset flavor within the test class

    - fixtures
      - are not defined in the base suite but are passed, unpacked, and used
      - are defined in the tests where they are used
        - for modularity, the basic contract factory fixture is always called `contract_factory`

## Creating Pull Requests (PRs)

As a contributor, you are expected to fork this repository, work on your own fork and then submit pull requests. The pull requests will be reviewed and eventually merged into the main repo. See ["Fork-a-Repo"](https://help.github.com/articles/fork-a-repo/) for how this works.

## A typical workflow

1. Make sure your fork is up to date with the main repository:

    ```sh
    cd cairo-contracts
    git remote add upstream https://github.com/OpenZeppelin/cairo-contracts.git
    git fetch upstream
    git pull --rebase upstream main
    ```

    > NOTE: The directory `cairo-contracts` represents your fork's local copy.

2. Branch out from `main` into `fix/some-bug-short-description-#123` (ex: `fix/typos-in-docs-#123`):

    (Postfixing #123 will associate your PR with the issue #123 and make everyone's life easier =D)

    ```sh
    git checkout -b fix/some-bug-short-description-#123
    ```

3. Make your changes, add your files, update documentation ([see Documentation section](#documentation)), commit, and push to your fork.

    ```sh
    git add SomeFile.js
    git commit "Fix some bug short description #123"
    git push origin fix/some-bug-short-description-#123
    ```

4. Run tests, linter, etc. This can be done by running local continuous integration and make sure it passes. We recommend to use a [python virtual environment](https://docs.python.org/3/tutorial/venv.html).

    ```bash
    # install tox from testing dependencies
    pip install .[testing] # '.[testing]' in zsh

    # run tests
    tox

    # stop the build if there are Markdown documentation errors
    tox -e lint
    ```

5. Go to [github.com/OpenZeppelin/cairo-contracts](https://github.com/OpenZeppelin/cairo-contracts) in your web browser and issue a new pull request.
    Begin the body of the PR with "Fixes #123" or "Resolves #123" to link the PR to the issue that it is resolving.
    *IMPORTANT* Read the PR template very carefully and make sure to follow all the instructions. These instructions
    refer to some very important conditions that your PR must meet in order to be accepted, such as making sure that all PR checks pass.

6. Maintainers will review your code and possibly ask for changes before your code is pulled in to the main repository. We'll check that all tests pass, review the coding style, and check for general code correctness. If everything is OK, we'll merge your pull request and your code will be part of OpenZeppelin Contracts for Cairo.

    *IMPORTANT* Please pay attention to the maintainer's feedback, since its a necessary step to keep up with the standards OpenZeppelin Contracts attains to.

## Documentation

Before submitting the PR, you must update the corresponding documentation entries in the docs folder. In the future we may use something similar to solidity-docgen to automatically generate docs, but for now we are updating .adoc entries manually.

If you want to run the documentation UI locally:

1. Change directory into docs inside the project and run npm install.

    ```bash
    cd docs && npm i
    ```

2. Build the docs and run the local server (default to localhost:8080). This will watch for changes in the docs/module folder, and update the UI accordingly.

    ```bash
    npm run docs:watch
    ```

## Integration tests

Currently, [starknet's test suite](https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/testing/starknet.py) has important differences with public networks. Like [not checking signature hints toward the end of the tx flow](https://github.com/OpenZeppelin/cairo-contracts/issues/386).

That's why we strongly suggest testing new features against a testnet before submitting the PR, to make sure that everything works as expected in a real environment.

We are looking into defining a better process for these integration tests, but for now the PR author/contributor must suggest an approach to test the feature when applicable, which has to be agreed and reproduced by the reviewer.

## All set

If you have any questions, feel free to post them to github.com/OpenZeppelin/cairo-contracts/issues.

Finally, if you're looking to collaborate and want to find easy tasks to start, look at the issues we marked as ["Good first issue"](https://github.com/OpenZeppelin/cairo-contracts/labels/good%20first%20issue).

Thanks for your time and code!
