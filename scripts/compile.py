#!/usr/bin/env python
import sys, os, subprocess
from config import CONTRACTS_DIRECTORY, BUILD_DIRECTORY, ABIS_DIRECTORY


def compile(params):
  """
  $ compile.py 
    Compiles all contracts in CONTRACTS_DIRECTORY

  $ compile.py contracts/MyContract.cairo
    Compiles MyContract.cairo

  $ compile.py contracts/foo.cairo contracts/bar.cairo
    Compiles foo.cairo and bar.cairo
  """

  # to do: automatically support subdirectories

  if not os.path.exists(ABIS_DIRECTORY):
    print("Creating {} to store compilation artifacts".format(ABIS_DIRECTORY))
    os.makedirs(ABIS_DIRECTORY, exist_ok=True)

  if len(params) == 0:
    print("🤖 Compiling all Cairo contracts in the {} directory".format(CONTRACTS_DIRECTORY))
    for path in get_all_contracts():
      compile_contract(path)
  elif len(params) == 1:
    compile_contract(params[0])
  else:
    for path in params[1:]:
      compile_contract(path)
  
  print("✅ Done")

def compile_contract(path):
  base = os.path.basename(path)
  filename = os.path.splitext(base)[0]
  print("🔨 Compiling {}".format(path))

  cmd = """
  starknet-compile {path} \
    --cairo_path={CONTRACTS_DIRECTORY}
    --output {BUILD_DIRECTORY}{filename}.json \
    --abi {ABIS_DIRECTORY}{filename}.json
  """.format(
    path=path,
    CONTRACTS_DIRECTORY=CONTRACTS_DIRECTORY,
    BUILD_DIRECTORY=BUILD_DIRECTORY,
    ABIS_DIRECTORY=ABIS_DIRECTORY,
    filename=filename)

  process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
  output, error = process.communicate()


def get_all_contracts():
  for filename in os.listdir(CONTRACTS_DIRECTORY):
    if filename.endswith(".cairo"):
        yield os.path.join(CONTRACTS_DIRECTORY, filename)


if __name__ == "__main__":
  compile(sys.argv[1:])
