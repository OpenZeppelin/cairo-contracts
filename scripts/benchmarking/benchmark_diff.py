import subprocess
import json
import sys

from benchmark import BYTECODE_KEY, CONTRACT_CLASS_KEY, try_get_name

# ANSI color codes
RESET   = "\033[0m"
BOLD    = "\033[1m"
YELLOW  = "\033[33m"
GREEN   = "\033[32m"
RED     = "\033[31m"
CYAN    = "\033[36m"
GRAY    = "\033[90m"

# Starknet limits
MAX_BYTECODE_SIZE = 81920 # felts
MAX_CONTRACT_CLASS_SIZE = 4089446 # bytes

CLOSE_TO_LIMIT = 0.8


def load_json(path):
    with open(path, "r") as f:
        return json.load(f)


def get_size_warning(metric, value, color=True):
    if value is None:
        return ""
    if metric == "felts":
        limit = MAX_BYTECODE_SIZE
    elif metric == "bytes":
        limit = MAX_CONTRACT_CLASS_SIZE
    else:
        return ""
    if value >= limit:
        return f"{RED if color else ''}{'❌ OVER LIMIT'}{RESET if color else ''}"
    elif value >= CLOSE_TO_LIMIT * limit:
        return f"{YELLOW if color else ''}{'⚠️  NEAR LIMIT'}{RESET if color else ''}"
    return ""


def get_current_benchmark(benchmark_script, target_dir=None):
    cmd = [sys.executable, benchmark_script, "--json"]
    if target_dir:
        cmd.extend(["--dir", target_dir])
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        print(f"{RED}Error running benchmark script:\n{proc.stderr}{RESET}")
        sys.exit(1)
    return json.loads(proc.stdout)


def print_diff(old, new):
    print(f"\n{BOLD}{CYAN}--- BYTECODE SIZE (felts) ---{RESET}")
    compare_subdicts(old.get(BYTECODE_KEY, {}), new.get(BYTECODE_KEY, {}), "felts")

    print(f"\n{BOLD}{CYAN}--- SIERRA CONTRACT CLASS SIZE (bytes) ---{RESET}")
    compare_subdicts(old.get(CONTRACT_CLASS_KEY, {}), new.get(CONTRACT_CLASS_KEY, {}), "bytes")


def color_name(name):
    return f"{BOLD}{YELLOW}{name}{RESET}"


def compare_subdicts(old, new, metric):
    all_files = set(old.keys()) | set(new.keys())
    for file in sorted(all_files):
        old_val = old.get(file, {}).get(metric)
        new_val = new.get(file, {}).get(metric)
        file_name = color_name(try_get_name(file))
        if old_val is None and new_val is not None:
            value = f"{GREEN}{metric} = {new_val}{RESET}"
            warning = get_size_warning(metric, new_val)
            print(f"{GREEN}+ {file_name}: {value} (NEW) {warning}{RESET}")
        elif old_val is not None and new_val is None:
            value = f"{RED}{metric} = {old_val}{RESET}"
            print(f"{RED}- {file_name}: {value} (REMOVED){RESET}")
        elif old_val is not None and new_val is not None:
            if old_val == new_val:
                value = f"{GRAY}{metric} = {new_val} (no change){RESET}"
                print(f"{GRAY}= {file_name}: {value}")
            else:
                diff = new_val - old_val
                if diff > 0:
                    arrow = f"{GREEN}↑{RESET}"
                    old_s = f"{RED}{old_val}{RESET}"
                    new_s = f"{GREEN}{new_val}{RESET}"
                else:
                    arrow = f"{RED}↓{RESET}"
                    old_s = f"{RED}{old_val}{RESET}"
                    new_s = f"{RED}{new_val}{RESET}"
                warning = get_size_warning(metric, new_val)
                print(f"* {file_name}: {old_s} → {new_s} ({arrow}{abs(diff)}) {warning}")


def print_diff_markdown(old, new):
    print(f"#### BYTECODE SIZE (felts) (limit: {MAX_BYTECODE_SIZE:,} felts)\n")
    markdown_subtable(old.get(BYTECODE_KEY, {}), new.get(BYTECODE_KEY, {}), "felts")

    print(f"#### SIERRA CONTRACT CLASS SIZE (bytes) (limit: {MAX_CONTRACT_CLASS_SIZE:,} bytes)\n")
    markdown_subtable(old.get(CONTRACT_CLASS_KEY, {}), new.get(CONTRACT_CLASS_KEY, {}), "bytes")


def markdown_subtable(old, new, metric, show_unchanged=False):
    all_files = sorted(set(old.keys()) | set(new.keys()))
    rows = []

    # Header
    rows.append(["Contract", "Old", "New", "Δ", "Note"])

    # Data rows
    for file in all_files:
        name = try_get_name(file)
        old_val = old.get(file, {}).get(metric)
        new_val = new.get(file, {}).get(metric)

        if old_val is None and new_val is not None:
            delta = f"+{new_val}"
            note = f"✅ NEW"
            warning = get_size_warning(metric, new_val, color=False)
            if warning:
                note += f" ({warning})"
            rows.append([f"`{name}`", "—", str(new_val), delta, note])
        elif old_val is not None and new_val is None:
            delta = f"-{old_val}"
            rows.append([f"`{name}`", str(old_val), "—", delta, "❌ REMOVED"])
        elif old_val == new_val:
            if show_unchanged:
                rows.append([f"`{name}`", str(old_val), str(new_val), "0", "⚪ No change"])
        else:
            diff = new_val - old_val
            arrow = "🟢" if diff > 0 else "🔴"
            sign = "+" if diff > 0 else "−"
            delta = f"{arrow} {sign}{abs(diff)}"
            note = get_size_warning(metric, new_val)
            rows.append([f"`{name}`", str(old_val), str(new_val), delta, note or ""])

    if len(rows) == 1:
        print(f"No changes in {metric}.")
        return

    # Calculate column widths
    col_widths = [max(len(cell) for cell in col) for col in zip(*rows)]

    # Format table
    def format_row(row):
        return "| " + " | ".join(cell.ljust(w) for cell, w in zip(row, col_widths)) + " |"

    # Print header and separator
    print(format_row(rows[0]))
    print("|" + "|".join("-" * (w + 2) for w in col_widths) + "|")

    # Print data rows
    for row in rows[1:]:
        print(format_row(row))


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Diff Cairo contract benchmarks.")
    parser.add_argument("benchmark_script", help="Path to benchmark.py")
    parser.add_argument("previous_json", help="Path to previous JSON benchmark file")
    parser.add_argument("--dir", type=str, help="Target directory for new benchmark (optional)")
    parser.add_argument("--markdown", action="store_true", help="Output results as a markdown table")
    args = parser.parse_args()

    prev = load_json(args.previous_json)
    current = get_current_benchmark(args.benchmark_script, args.dir)

    if args.markdown:
        print_diff_markdown(prev, current)
    else:
        print_diff(prev, current)
