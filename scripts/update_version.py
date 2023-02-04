import fileinput
import itertools
import sys
from pathlib import Path

CURRENT_VERSION = "v0.6.1"
OTHER_PATHS = ["docs/antora.yml", "README.md"]


def main():
    bump_type = str(sys.argv[1])
    new_version = _bump_version(bump_type)
    src_path = Path("src")
    docs_path = Path("docs")
    for p in itertools.chain(
        src_path.glob("**/*.cairo"),
        docs_path.glob("**/*.adoc"), OTHER_PATHS):
        _update_version(p, new_version)
    _update_version("scripts/update_version.py", new_version)
    print(new_version)


def _bump_version(bump_type):
    maj, min, pat = CURRENT_VERSION.split(".")
    split_list = []

    if bump_type == "major":
        new_maj = int(maj.strip("v")) + 1
        split_list = ["v" + str(new_maj), "0", "0"]
    elif bump_type == "minor":
        new_min = int(min) + 1
        split_list = [maj, new_min, "0"]
    else:
        if pat[-1].isalpha():
            # Removes char e.g. 0.1.2a => 0.1.2
            new_pat = int(pat[:-1])
        else:
            new_pat = int(pat) + 1
        split_list = [maj, min, new_pat]

    return ".".join(map(str, split_list))


def _update_version(path, version):
    with fileinput.input(path, inplace=True) as file:
        for line in file:
            old, new = CURRENT_VERSION, version
            if path in OTHER_PATHS:
                old = old.strip("v")
                new = new.strip("v")
            new_line = line.replace(old, new)
            print(new_line, end="")


if __name__ == "__main__":
    main()
