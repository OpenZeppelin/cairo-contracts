import fileinput
import itertools
import sys
from pathlib import Path

CURRENT_VERSION = "v0.4.0b"
DOC_PATHS = ["docs/antora.yml", "README.md"]


def main():
    new_version = str(sys.argv[1])
    path = Path("src")
    for p in itertools.chain(path.glob("**/*.cairo"), DOC_PATHS):
        _update_version(p, new_version)
    _update_version("scripts/update_version.py", new_version)


def _update_version(path, version):
    with fileinput.input(path, inplace=True) as file:
        for line in file:
            old, new = CURRENT_VERSION, version
            if path in DOC_PATHS:
                old = old.strip("v")
                new = new.strip("v")
            new_line = line.replace(old, new)
            print(new_line, end="")


if __name__ == "__main__":
    main()
