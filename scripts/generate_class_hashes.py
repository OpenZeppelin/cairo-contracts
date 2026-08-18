#!/usr/bin/env python3
"""Generate preset class-hash constants for the external documentation repository."""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

REPO_ROOT = Path(__file__).resolve().parents[1]
TARGET_DIR = REPO_ROOT / "target"
ARTIFACT_MANIFEST = TARGET_DIR / "release/openzeppelin_presets.starknet_artifacts.json"
PRESET_ORDER = [
    "AccountUpgradeable",
    "ERC20Upgradeable",
    "ERC721Upgradeable",
    "ERC1155Upgradeable",
    "EthAccountUpgradeable",
    "MetaTransactionV0",
    "UniversalDeployer",
    "VestingWallet",
]
HASH_PATTERN = re.compile(r"^0x[0-9a-fA-F]+$")
SCARB_VERSION_PATTERN = re.compile(r'^scarb-version\s*=\s*"([^"]+)"\s*$', re.MULTILINE)
STARK_FIELD_PRIME = 2 ** 251 + 17 * 2 ** 192 + 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate JavaScript constants for the preset class hashes in OpenZeppelin docs."
    )
    parser.add_argument(
        "--no-build",
        action="store_true",
        help="Reuse existing release artifacts instead of building openzeppelin_presets.",
    )
    parser.add_argument(
        "--scarb-version",
        help="Override the scarb version read from the workspace Scarb.toml.",
    )
    return parser.parse_args()


def read_scarb_version() -> str:
    manifest = (REPO_ROOT / "Scarb.toml").read_text(encoding="utf-8")
    match = SCARB_VERSION_PATTERN.search(manifest)
    if match is None:
        raise ValueError("could not find workspace scarb-version in Scarb.toml")
    return match.group(1)


def build_presets() -> None:
    subprocess.run(
        [
            "scarb",
            "--manifest-path",
            str(REPO_ROOT / "Scarb.toml"),
            "--target-dir",
            str(TARGET_DIR),
            "--release",
            "build",
            "-p",
            "openzeppelin_presets",
        ],
        cwd=REPO_ROOT,
        check=True,
        stdout=sys.stderr,
    )


def read_artifact_manifest() -> Any:
    with ARTIFACT_MANIFEST.open(encoding="utf-8") as manifest_file:
        return json.load(manifest_file)


def normalize_hash(value: Any) -> str:
    if not isinstance(value, str) or HASH_PATTERN.fullmatch(value) is None:
        raise ValueError(f"invalid Sierra class hash: {value!r}")

    digits = value[2:].lower()
    if len(digits) > 64:
        raise ValueError(f"Sierra class hash exceeds 32 bytes: {value}")
    if int(digits, 16) >= STARK_FIELD_PRIME:
        raise ValueError(f"Sierra class hash is outside the Stark field: {value}")
    return f"0x{digits.zfill(64)}"


def extract_preset_artifacts(payload: Any) -> Dict[str, Path]:
    if not isinstance(payload, dict):
        raise ValueError("Scarb artifact manifest must be an object")

    contracts = payload.get("contracts")
    if not isinstance(contracts, list):
        raise ValueError("Scarb artifact manifest must contain a contracts list")

    artifacts: Dict[str, Path] = {}
    for contract in contracts:
        if not isinstance(contract, dict):
            raise ValueError("each contract entry must be an object")

        name = contract.get("contract_name")
        if not isinstance(name, str) or not name:
            raise ValueError("each contract entry must have a contract_name")
        if name in artifacts:
            raise ValueError(f"duplicate preset contract: {name}")

        contract_artifacts = contract.get("artifacts")
        if not isinstance(contract_artifacts, dict):
            raise ValueError(f"preset contract has no artifacts object: {name}")
        sierra_file = contract_artifacts.get("sierra")
        if not isinstance(sierra_file, str) or not sierra_file:
            raise ValueError(f"preset contract has no Sierra artifact: {name}")

        artifacts[name] = ARTIFACT_MANIFEST.parent / sierra_file

    if not artifacts:
        raise ValueError("Scarb artifact manifest contains no preset contracts")

    missing = [name for name in PRESET_ORDER if name not in artifacts]
    unexpected = sorted(name for name in artifacts if name not in PRESET_ORDER)
    if missing or unexpected:
        differences = []
        if missing:
            differences.append(f"missing: {', '.join(missing)}")
        if unexpected:
            differences.append(f"unexpected: {', '.join(unexpected)}")
        raise ValueError(
            f"preset artifacts do not match the documentation constants ({'; '.join(differences)})"
        )
    return artifacts


def compute_class_hash(artifact: Path) -> str:
    if not artifact.is_file():
        raise ValueError(f"Sierra artifact not found: {artifact}")

    result = subprocess.run(
        ["starkli", "class-hash", str(artifact)],
        cwd=REPO_ROOT,
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return normalize_hash(result.stdout.strip())


def compute_preset_hashes(artifacts: Dict[str, Path]) -> Dict[str, str]:
    return {name: compute_class_hash(artifact) for name, artifact in artifacts.items()}


def ordered_names(hashes: Dict[str, str]) -> List[str]:
    preferred_positions = {name: index for index, name in enumerate(PRESET_ORDER)}
    return sorted(
        hashes,
        key=lambda name: (preferred_positions.get(name, len(PRESET_ORDER)), name),
    )


def format_constants(scarb_version: str, hashes: Dict[str, str]) -> str:
    lines = [
        f'export const CLASS_HASH_SCARB_VERSION = "{scarb_version}";',
        "",
        "export const CLASS_HASHES = {",
    ]
    for name in ordered_names(hashes):
        lines.extend(
            [
                f"\t{name}ClassHash:",
                f'\t\t"{hashes[name]}",',
            ]
        )
    lines.extend(["};", ""])
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    try:
        if not args.no_build:
            build_presets()
        artifacts = extract_preset_artifacts(read_artifact_manifest())
        scarb_version = args.scarb_version or read_scarb_version()
        hashes = compute_preset_hashes(artifacts)
        print(format_constants(scarb_version, hashes), end="")
    except FileNotFoundError as error:
        print(f"error: required file or command not found: {error.filename}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as error:
        print(f"error: command failed with exit code {error.returncode}", file=sys.stderr)
        return error.returncode or 1
    except (json.JSONDecodeError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
