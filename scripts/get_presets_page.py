import sys
import json

def main():
    # Required compiler version argument
    cmp_version = sys.argv[1]

    # Read class hashes from stdin
    contracts = json.load(sys.stdin)

    print(generate_doc_file(cmp_version, contracts))


def generate_doc_file(cmp_version, contracts):
    header = f"""// Version
:class-hash-cairo-version: \
https://crates.io/crates/cairo-lang-compiler/{cmp_version}[cairo {cmp_version}]
"""
    hashes = "// Class Hashes\n"
    for contract in contracts['contracts']:
        # The [13:] is to remove the "openzeppelin_" prefix from the contract name
        hashes += f":{contract['name'][13:]}-class-hash: {contract['sierra']}\n"

    footer = """// Presets page
:presets-page: xref:presets.adoc[Sierra class hash]"""

    return f"{header}\n\n{hashes}\n\n{footer}\n"


if __name__ == '__main__':
    main()
