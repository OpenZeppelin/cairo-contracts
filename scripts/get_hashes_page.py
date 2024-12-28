import sys
import json

KNOWN_ORDER = [
    "ERC20Upgradeable",
    "ERC721Upgradeable",
    "ERC1155Upgradeable",
    "AccountUpgradeable",
    "EthAccountUpgradeable",
    "UniversalDeployer"
]

def main():
    cmp_version = sys.argv[1]  # Compiler version argument
    contracts = json.load(sys.stdin)  # Read JSON from stdin
    print(generate_doc_file(cmp_version, contracts))

def generate_doc_file(cmp_version, contracts):
    header = f"""// Version
:class-hash-cairo-version: \
https://crates.io/crates/cairo-lang-compiler/{cmp_version}[cairo {cmp_version}]
"""
    # Remove prefixes and sort contracts by name
    contracts['contracts'] = [
        {**contract, 'name': contract['name'].removeprefix('openzeppelin_presets_')}
        for contract in contracts['contracts']
    ]
    contracts['contracts'].sort(key=lambda c: c['name'])

    # Generate known order hashes and other hashes
    known_hashes = get_known_order_hashes(contracts['contracts'])
    other_hashes = [
        f":{contract['name']}-class-hash: {normalize_len(contract['sierra'])}"
        for contract in contracts['contracts']
        if contract['name'] not in KNOWN_ORDER and "Mock" not in contract['name']
    ]

    footer = """// Presets page
:presets-page: xref:presets.adoc[Sierra class hash]"""

    return f"{header}\n// Class Hashes\n{known_hashes}{'\n'.join(other_hashes)}\n\n{footer}\n"

def get_known_order_hashes(contracts):
    known_hashes = [
        f":{contract['name']}-class-hash: {normalize_len(contract['sierra'])}"
        for contract in contracts
        if contract['name'] in KNOWN_ORDER
    ]
    # Ensure the hashes are sorted according to KNOWN_ORDER
    return '\n'.join(sorted(known_hashes, key=lambda h: KNOWN_ORDER.index(h.split('-class-hash:')[0][1:])))

def normalize_len(sierra_hash):
    return "0x" + sierra_hash[2:].zfill(64)

if __name__ == '__main__':
    main()
