import fileinput
import sys
from pathlib import Path

CURRENT_VERSION = "v0.3.0"
ANTORA_PATH = "docs/antora.yml"


def main():
    new_version = str(sys.argv[1])
    path = Path("src")
    for p in path.glob("**/*.cairo"):
        _update_version(p, new_version)
    _update_version(ANTORA_PATH, new_version)
    _update_version("scripts/update_version.py", new_version)


def _update_version(path, version):
    with fileinput.input(path, inplace=True) as file:
        for line in file:
            old, new = CURRENT_VERSION, version
            if path == ANTORA_PATH:
                old = old.strip("v")
                new = new.strip("v")
            new_line = line.replace(old, new)
            print(new_line, end="")


if __name__ == "__main__":
    main()
