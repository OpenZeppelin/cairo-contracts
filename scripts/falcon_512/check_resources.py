#!/usr/bin/env python3
"""Compile release Falcon presets to CASM and enforce declaration-size budgets.

Build with `scarb --release build -p openzeppelin_presets` first. Universal Sierra
Compiler must be on PATH. These checks do not establish network libfunc/version support.
"""

import json
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PRESETS = (
    "Falcon512ShakeAccountUpgradeable",
    "Falcon512ShakeDirectAccountUpgradeable",
)
# https://docs.starknet.io/learn/cheatsheets/chain-info (recheck on network upgrades).
MAX_BYTECODE_FELTS = 81_920
MAX_CLASS_BYTES = 4_089_446
# Repository regression budgets leave room below the protocol limits.
BUDGETS = {"sierra_felts": 60_000, "casm_felts": 50_000, "artifact_bytes": 2_000_000}


def validate_sizes(sizes: dict[str, int]) -> None:
    for name, budget in BUDGETS.items():
        if not 0 < sizes[name] <= budget:
            raise ValueError(f"{name}: {sizes[name]} exceeds budget {budget} or is empty")
    if max(sizes["sierra_felts"], sizes["casm_felts"]) > MAX_BYTECODE_FELTS:
        raise ValueError("bytecode exceeds declaration limit")
    # Including debug info and whitespace makes this stricter than the serialized class check.
    if sizes["artifact_bytes"] > MAX_CLASS_BYTES:
        raise ValueError("class exceeds declaration limit")


def main() -> None:
    subprocess.run(["universal-sierra-compiler", "--version"], check=True)
    with tempfile.TemporaryDirectory(prefix="falcon-casm-") as temporary:
        for preset in PRESETS:
            sierra = REPO_ROOT / f"target/release/openzeppelin_presets_{preset}.contract_class.json"
            casm = Path(temporary) / f"{preset}.casm.json"
            subprocess.run(
                ["universal-sierra-compiler", "compile-contract", "--sierra-path", str(sierra),
                 "--output-path", str(casm)],
                check=True,
            )
            sizes = {
                "sierra_felts": len(json.loads(sierra.read_text())["sierra_program"]),
                "casm_felts": len(json.loads(casm.read_text())["bytecode"]),
                "artifact_bytes": sierra.stat().st_size,
            }
            validate_sizes(sizes)
            print(json.dumps({"contract": preset, **sizes}))


if __name__ == "__main__":
    main()
