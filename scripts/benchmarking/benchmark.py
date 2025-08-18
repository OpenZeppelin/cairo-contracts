import os
import json
import sys
import argparse

# ANSI color codes (no external dependencies)
RESET   = "\033[0m"
BOLD    = "\033[1m"
YELLOW  = "\033[33m"
GREEN   = "\033[32m"
RED     = "\033[31m"
CYAN    = "\033[36m"

# Set the path to your Scarb release output, e.g., "target/release"
TARGET_DIR = "target/release"

# Keys for the JSON output
BYTECODE_KEY = "bytecode"
CONTRACT_CLASS_KEY = "contract_class"

def try_get_name(filename):
    """
    Extracts the contract name from the filename:
    - Starts at the first uppercase letter.
    - Ends at the next '.' or end of string.
    Returns the filename if no uppercase letter is found.
    """
    for i, c in enumerate(filename):
        if c.isupper():
            start = i
            end = filename.find('.', start)
            if end == -1:
                return filename[start:]
            else:
                return filename[start:end]
    return filename


def get_bytecode_size(json_path):
    with open(json_path, "r") as f:
        data = json.load(f)
    bytecode = data.get(BYTECODE_KEY, [])
    num_felts = len(bytecode)
    return num_felts


def get_sierra_contract_class_size(json_path):
    num_bytes = os.path.getsize(json_path)
    return num_bytes


def benchmark_contracts(target_dir):
    results = {BYTECODE_KEY: {}, CONTRACT_CLASS_KEY: {}}
    for file in os.listdir(target_dir):
        if file.endswith(".compiled_contract_class.json"):
            path = os.path.join(target_dir, file)
            try:
                num_felts = get_bytecode_size(path)
                results[BYTECODE_KEY][file] = {"felts": num_felts}
            except Exception as e:
                results[BYTECODE_KEY][file] = {"error": str(e)}
        elif file.endswith(".contract_class.json"):
            path = os.path.join(target_dir, file)
            try:
                num_bytes = get_sierra_contract_class_size(path)
                results[CONTRACT_CLASS_KEY][file] = {"bytes": num_bytes}
            except Exception as e:
                results[CONTRACT_CLASS_KEY][file] = {"error": str(e)}
    return results


def print_benchmark_results(results):
    print(f"{BOLD}{CYAN}CASM bytecode sizes:{RESET}")
    for file, info in results[BYTECODE_KEY].items():
        name = f"{BOLD}{YELLOW}{try_get_name(file)}{RESET}"
        if "felts" in info:
            value = f"{BOLD}{GREEN}{info['felts']} felts{RESET}"
            print(f"{name}: {value}")
        else:
            print(f"{RED}Error processing {file}: {info['error']}{RESET}")

    print(f"\n{BOLD}{CYAN}Sierra contract class sizes:{RESET}")
    for file, info in results[CONTRACT_CLASS_KEY].items():
        name = f"{BOLD}{YELLOW}{try_get_name(file)}{RESET}"
        if "bytes" in info:
            num_bytes = info["bytes"]
            value = f"{BOLD}{GREEN}{num_bytes} bytes{RESET} ({num_bytes/1024:.2f} KB)"
            print(f"{name}: {value}")
        else:
            print(f"{RED}Error processing {file}: {info['error']}{RESET}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Benchmark Cairo contract artifact sizes.")
    parser.add_argument("--json", action="store_true", help="Output results as JSON.")
    parser.add_argument("--dir", type=str, default=TARGET_DIR, help="Target directory (default: target/release)")
    args = parser.parse_args()

    results = benchmark_contracts(args.dir)
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print(f"{BOLD}Benchmarking CASM and Sierra contract class sizes in: {args.dir}\n{RESET}")
        print_benchmark_results(results)
