#!/usr/bin/env python3
import argparse
import os
import re
from typing import Tuple

ROOT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "packages", "access"))

def parse_args() -> Tuple[str, str, str]:
    p = argparse.ArgumentParser(description="Update README.md links for versioning rules.")
    p.add_argument("--new-version", required=True, help="New library version (e.g. 3.0.0 or 3.0.0-alpha.2)")
    p.add_argument("--current-version", required=True, help="Current library version (e.g. 2.5.1 or 2.5.1-alpha)")
    p.add_argument("--root", default=ROOT_DIR, help="Root directory (default: ../packages)")
    args = p.parse_args()
    return args.new_version.strip(), args.current_version.strip(), os.path.abspath(args.root)

def major_of(v: str) -> str:
    # Extract major version number from a semver-like string: e.g., "3.0.0" -> "3"
    # Falls back to empty string if not found.
    m = re.match(r"^\s*(\d+)(?:\.\d+){0,2}\s*(?:[-+].*)?$", v)
    return m.group(1) if m else ""

def update_file_contents(
    text: str,
    new_version: str,
    current_version: str,
) -> str:
    """
    Apply the three rules:
      1) current contains 'alpha' and new contains 'alpha'  -> do nothing
      2) current contains 'alpha' and new does not          -> replace '/alpha/' with '/<new_major>.x/' (in links)
      3) current does not contain 'alpha' and new contains 'alpha' -> replace '/<current_major>.x/' with '/alpha/' (in links)
      4) current does not contain 'alpha' and new does not contain 'alpha' -> replace '/<current_major>.x/' with '/<new_major>.x/' (in links)
    Only updates content that appears inside markdown link/image URLs, i.e., inside parentheses (...).
    """
    cur_has_alpha = "alpha" in current_version.lower()
    new_has_alpha = "alpha" in new_version.lower()

    if cur_has_alpha and new_has_alpha:
        return text  # Rule 1: no-op

    # Helper: replace only when inside (...) to target markdown links/images
    def replace_inside_parens(pattern: str, repl: str, s: str) -> str:
        # We match the opening '(' separately to keep it intact, and ensure we only touch content within a single URL segment.
        return re.sub(pattern, repl, s)

    if cur_has_alpha and not new_has_alpha:
        # Rule 2: /alpha/  ->  /<new_major>.x/
        new_major = major_of(new_version)
        if not new_major:
            # If we can't parse a major, do nothing safely.
            return text
        # Replace occurrences of "/alpha/" that appear within parentheses
        # pattern captures '(' then any non-')' chars (lazy), then '/alpha/'
        pattern = r"(\()([^)]*?)/alpha/"
        replacement = r"\1\2/" + f"{new_major}.x" + "/"
        return replace_inside_parens(pattern, replacement, text)

    if (not cur_has_alpha) and new_has_alpha:
        # Rule 3: '/<current_major>.x/' -> '/alpha/' (within links)
        cur_major = major_of(current_version)
        if not cur_major:
            return text
        # Escape the dot in '<major>.x'
        pattern = r"(\()([^)]*)/" + re.escape(f"{cur_major}.x") + r"/"
        replacement = r"\1\2/alpha/"
        return replace_inside_parens(pattern, replacement, text)

    if not cur_has_alpha and not new_has_alpha:
        # Rule 4: '/<current_major>.x/' -> '/<new_major>.x/' (within links)
        cur_major = major_of(current_version)
        new_major = major_of(new_version)
        if not cur_major or not new_major:
            return text
        pattern = r"(\()([^)]*)/" + re.escape(f"{cur_major}.x") + r"/"
        replacement = r"\1\2/" + f"{new_major}.x" + "/"
        return replace_inside_parens(pattern, replacement, text)

    # If neither has alpha, the rules say nothing—leave file unchanged.
    return text

def find_readmes(root: str):
    for dirpath, dirnames, filenames in os.walk(root):
        for name in filenames:
            if name.lower() == "readme.md":
                yield os.path.join(dirpath, name)

def main():
    new_version, current_version, root = parse_args()

    if not os.path.isdir(root):
        print(f"[warn] Root directory not found: {root}")
        return

    changed_files = 0
    scanned_files = 0

    for path in find_readmes(root):
        scanned_files += 1
        try:
            with open(path, "r", encoding="utf-8") as f:
                original = f.read()
        except Exception as e:
            print(f"[error] Could not read {path}: {e}")
            continue

        updated = update_file_contents(original, new_version, current_version)

        if updated != original:
            try:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(updated)
                changed_files += 1
                print(f"[updated] {path}")
            except Exception as e:
                print(f"[error] Could not write {path}: {e}")

    print(f"\nDone. Scanned: {scanned_files} README.md files. Updated: {changed_files}.")

if __name__ == "__main__":
    main()
